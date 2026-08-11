package com.example.stream_hub

import android.app.Activity
import android.app.AlertDialog
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.GradientDrawable
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.TextureView
import android.view.View
import android.view.ViewGroup
import android.view.Window
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import android.widget.Toast
import androidx.annotation.OptIn
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.Player
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.Tracks
import androidx.media3.common.VideoSize
import androidx.media3.common.util.UnstableApi
import androidx.media3.common.util.Util
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.dash.DashMediaSource
import androidx.media3.exoplayer.hls.HlsMediaSource
import androidx.media3.exoplayer.mediacodec.MediaCodecSelector
import androidx.media3.exoplayer.rtsp.RtspMediaSource
import androidx.media3.exoplayer.source.MediaSource
import androidx.media3.exoplayer.source.ProgressiveMediaSource
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Fullscreen native video player, rendered OUTSIDE the Flutter view hierarchy.
 *
 * Flutter's Android compositing paths are broken for video on Unisoc/Mali
 * devices (see docs/PLAYBACK_ENGINEERING.md §1.1 and §8.3):
 *  - Flutter external textures: the GL consumer never samples frames.
 *  - Hybrid-composition platform views: SurfaceView frames reach SurfaceFlinger
 *    but are never composited; TextureView never initializes its surface.
 *
 * This Activity hosts a plain ExoPlayer + [android.view.TextureView] directly in
 * its content view. SurfaceView (which SurfaceFlinger composites as a separate
 * layer) and Flutter external textures both fail to display video on the itel
 * C671L (Unisoc ums9230/Mali): the BLASTBufferQueue can never acquire buffers
 * and Flutter's GL consumer never samples frames. TextureView renders through
 * the app's own view system, which is the only path proven to work.
 *
 * Control plane: the Dart side (`NativeActivityPlayerAdapter`) launches this
 * activity through the `stream_hub/native_player_launch` MethodChannel. State
 * flows back through the `stream_hub/native_player_events` MethodChannel, where
 * the Dart adapter registers the receiving handler. [companion] members give the
 * launch channel direct access to the live activity for transport commands.
 */
@OptIn(markerClass = [UnstableApi::class])
class NativePlayerActivity : Activity() {

    companion object {
        private const val EXTRA_URL = "url"
        private const val EXTRA_HEADERS = "headers"
        private const val EXTRA_TITLE = "title"
        private const val CHANNEL_EVENTS = "stream_hub/native_player_events"
        private const val CHANNEL_LAUNCH = "stream_hub/native_player_launch"
        private const val DEFAULT_USER_AGENT = "StreamHubPro/1.0 (Android)"
        private const val CONNECT_TIMEOUT_MS = 15_000
        private const val READ_TIMEOUT_MS = 15_000
        private const val POSITION_INTERVAL_MS = 500L
        private const val SEEK_STEP_MS = 10_000L
        private const val CONTROLS_AUTO_HIDE_MS = 4_000L

        /** Messenger of the live Flutter engine, set by [MainActivity]. */
        @Volatile
        var messenger: BinaryMessenger? = null

        /** The currently visible native player, if any. */
        @Volatile
        var instance: NativePlayerActivity? = null

        /** Launches the native player for [url] with [headers]. */
        fun launch(
            context: Context,
            url: String,
            headers: Map<String, String>,
            title: String? = null,
        ) {
            val intent = Intent(context, NativePlayerActivity::class.java)
                .putExtra(EXTRA_URL, url)
                .putExtra(EXTRA_HEADERS, HashMap(headers))
            if (!title.isNullOrEmpty()) {
                intent.putExtra(EXTRA_TITLE, title)
            }
            context.startActivity(intent)
        }
    }

    private var player: ExoPlayer? = null
    private var events: MethodChannel? = null
    private var volume = 1.0f
    private var muted = false

    private lateinit var root: FrameLayout
    private var videoSurface: TextureView? = null
    private var titleView: TextView? = null
    private var playPauseButton: TextView? = null
    private var qualityButton: TextView? = null
    private var loadingSpinner: ProgressBar? = null
    private var errorView: TextView? = null
    private var controlsVisible = true
    private var finishedNotified = false

    /// null = Auto (adaptive), otherwise the selected vertical resolution.
    private var selectedQuality: Int? = null

    private val mainHandler = Handler(Looper.getMainLooper())
    private val hideControlsRunnable = Runnable { setControlsVisible(false) }

    private val positionReporter = object : Runnable {
        override fun run() {
            emitPosition()
            mainHandler.postDelayed(this, POSITION_INTERVAL_MS)
        }
    }

    private val playerListener = object : Player.Listener {
        override fun onPlaybackStateChanged(playbackState: Int) {
            when (playbackState) {
                Player.STATE_BUFFERING -> {
                    emit("onState", mapOf("state" to "buffering"))
                    loadingSpinner?.visibility = View.VISIBLE
                }
                Player.STATE_READY -> {
                    loadingSpinner?.visibility = View.GONE
                    emit("onState", mapOf("state" to if (player?.playWhenReady == true) "playing" else "paused"))
                    emitPosition()
                }
                Player.STATE_ENDED -> {
                    loadingSpinner?.visibility = View.GONE
                    emit("onState", mapOf("state" to "completed"))
                }
                Player.STATE_IDLE -> {
                    loadingSpinner?.visibility = View.GONE
                }
            }
        }

        override fun onIsPlayingChanged(isPlaying: Boolean) {
            if (player?.playbackState == Player.STATE_READY) {
                emit("onState", mapOf("state" to if (isPlaying) "playing" else "paused"))
            }
            updatePlayPauseIcon()
        }

        override fun onVideoSizeChanged(videoSize: VideoSize) {
            if (videoSize.width > 0 && videoSize.height > 0) {
                emit("onVideo", mapOf("width" to videoSize.width, "height" to videoSize.height))
            }
        }

        override fun onPlayerError(error: PlaybackException) {
            loadingSpinner?.visibility = View.GONE
            showError("${error.errorCodeName}: ${error.message}")
            emit("onError", mapOf("message" to "${error.errorCodeName}: ${error.message}"))
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        instance = this
        events = messenger?.let { MethodChannel(it, CHANNEL_EVENTS) }

        setupWindow()
        root = FrameLayout(this)

        val exo = buildPlayer()
        player = exo
        val textureView = TextureView(this)
        videoSurface = textureView
        // ExoPlayer must own the TextureView output: setVideoTextureView applies
        // the aspect-ratio transform (fit/letterbox) and handles the
        // SurfaceTexture lifecycle. Setting a raw Surface via setVideoSurface
        // instead would stretch the stream to fill the whole screen, so a 16:9
        // video looks distorted while the device is held in portrait orientation.
        exo.setVideoTextureView(textureView)
        textureView.setOnClickListener { toggleControls() }
        root.setOnClickListener { toggleControls() }
        // The video surface must be the FIRST child of root: later children are
        // drawn on top, so adding it after the controls would let the rendered
        // frames cover the transport bar the moment playback begins.
        root.addView(
            textureView,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            ),
        )

        setupUi()
        parseIntent()
        exo.addListener(playerListener)

        load(exo)
    }

    private fun setupWindow() {
        requestWindowFeature(Window.FEATURE_NO_TITLE)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        window.setFlags(
            WindowManager.LayoutParams.FLAG_FULLSCREEN,
            WindowManager.LayoutParams.FLAG_FULLSCREEN,
        )
        window.decorView.systemUiVisibility =
            (View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_FULLSCREEN)
        // TextureView draws into the app's own window surface, so a transparent
        // window background is not required (unlike a SurfaceView, which sits
        // behind the window surface). Kept as a defensive fallback.
        window.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
    }

    private fun setupUi() {
        // `root` and the video surface are created in onCreate; the controls
        // added here are later siblings of the video surface and therefore
        // draw on top of it.
        loadingSpinner = ProgressBar(this, null, android.R.attr.progressBarStyleLarge).apply {
            visibility = View.GONE
        }
        root.addView(
            loadingSpinner,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER,
            ),
        )

        errorView = TextView(this).apply {
            textSize = 16f
            setTextColor(android.graphics.Color.WHITE)
            gravity = Gravity.CENTER
            visibility = View.GONE
        }
        root.addView(
            errorView,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER,
            ),
        )

        // Top bar: close button + the title of the channel being played.
        val topBar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        val backButton = TextView(this).apply {
            text = "\u2715"
            textSize = 28f
            setTextColor(android.graphics.Color.WHITE)
            gravity = Gravity.CENTER
            setPadding(24, 24, 24, 24)
            setOnClickListener { finish() }
        }
        titleView = TextView(this).apply {
            textSize = 20f
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            setTextColor(android.graphics.Color.WHITE)
            gravity = Gravity.CENTER_VERTICAL
            maxLines = 1
            ellipsize = android.text.TextUtils.TruncateAt.END
            setPadding(4, 0, 20, 0)
            setShadowLayer(4f, 0f, 2f, android.graphics.Color.BLACK)
        }
        topBar.addView(backButton)
        topBar.addView(
            titleView,
            LinearLayout.LayoutParams(
                0,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                1f,
            ),
        )
        root.addView(
            topBar,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.TOP,
            ),
        )

        // Bottom transport bar: rewind, play/pause, forward, stop.
        val bar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setBackgroundColor(-0x67000000)
            setPadding(0, 16, 0, 16)
        }
        val rewindButton = transportButton("\u23EA") { seekRelative(-SEEK_STEP_MS) }
        playPauseButton = transportButton("\u25B6") { togglePlayPause() }
        val forwardButton = transportButton("\u23E9") { seekRelative(SEEK_STEP_MS) }
        val stopButton = transportButton("\u23F9") { stopPlayback() }
        qualityButton = TextView(this).apply {
            text = "Auto"
            textSize = 18f
            setTextColor(android.graphics.Color.WHITE)
            gravity = Gravity.CENTER
            setPadding(22, 10, 22, 10)
            background = GradientDrawable().apply {
                setColor(-0x67000000)
                cornerRadius = 8f
            }
            setOnClickListener { showQualityDialog() }
        }
        bar.addView(rewindButton)
        bar.addView(playPauseButton)
        bar.addView(forwardButton)
        bar.addView(stopButton)
        bar.addView(
            qualityButton,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply { leftMargin = 16 },
        )
        root.addView(
            bar,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM,
            ),
        )
        updatePlayPauseIcon()

        setContentView(root)
        setControlsVisible(true)
    }

    private fun transportButton(
        icon: String,
        onClick: () -> Unit,
    ): TextView = TextView(this).apply {
        text = icon
        textSize = 36f
        setTextColor(android.graphics.Color.WHITE)
        gravity = Gravity.CENTER
        setPadding(30, 12, 30, 12)
        setOnClickListener { onClick() }
    }

    private fun seekRelative(deltaMs: Long) {
        val exo = player ?: return
        val duration = if (exo.duration == C.TIME_UNSET) Long.MAX_VALUE else exo.duration
        val target = (exo.currentPosition + deltaMs).coerceIn(0L, duration)
        exo.seekTo(target)
    }

    private fun stopPlayback() {
        val exo = player ?: return
        exo.stop()
        exo.playWhenReady = false
        updatePlayPauseIcon()
    }

    // ---- Video quality -------------------------------------------------------

    private fun showQualityDialog() {
        val exo = player ?: return
        val videoGroups = exo.currentTracks.groups
            .filter { it.type == C.TRACK_TYPE_VIDEO && it.length > 0 }
        if (videoGroups.isEmpty()) {
            Toast.makeText(
                this,
                "No video quality information available for this stream.",
                Toast.LENGTH_SHORT,
            ).show()
            return
        }
        val resolutions = LinkedHashSet<Int>()
        for (group in videoGroups) {
            for (i in 0 until group.length) {
                val height = group.getTrackFormat(i).height
                if (height > 0) resolutions.add(height)
            }
        }
        val sorted = resolutions.sorted()
        val labels = listOf("Auto (adaptive)") + sorted.map { "${it}p" }
        val currentIndex = selectedQuality?.let { sorted.indexOf(it) + 1 } ?: 0

        AlertDialog.Builder(this)
            .setTitle("Video quality")
            .setSingleChoiceItems(labels.toTypedArray(), currentIndex) { dialog, which ->
                if (which == 0) {
                    applyQuality(exo, null)
                } else {
                    applyQuality(exo, sorted[which - 1])
                }
                dialog.dismiss()
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun applyQuality(exo: ExoPlayer, resolution: Int?) {
        val builder = exo.trackSelectionParameters.buildUpon()
            .clearOverridesOfType(C.TRACK_TYPE_VIDEO)
        if (resolution != null) {
            val group = exo.currentTracks.groups.firstOrNull {
                it.type == C.TRACK_TYPE_VIDEO && it.length > 0
            }
            val index = group?.let { g ->
                (0 until g.length).firstOrNull { g.getTrackFormat(it).height == resolution }
            }
            if (group != null && index != null) {
                builder.setOverrideForType(
                    TrackSelectionOverride(group.mediaTrackGroup, listOf(index)),
                )
            } else {
                Toast.makeText(
                    this,
                    "$resolution" + "p is not available; keeping Auto.",
                    Toast.LENGTH_SHORT,
                ).show()
                selectedQuality = null
                exo.trackSelectionParameters = builder.build()
                updateQualityLabel()
                return
            }
        }
        selectedQuality = resolution
        exo.trackSelectionParameters = builder.build()
        updateQualityLabel()
    }

    private fun updateQualityLabel() {
        qualityButton?.text = selectedQuality?.let { "${it}p" } ?: "Auto"
    }

    private var streamUrl: String = ""
    private var headers: Map<String, String> = emptyMap()
    private var channelTitle: String? = null

    private fun parseIntent() {
        streamUrl = intent.getStringExtra(EXTRA_URL) ?: ""
        headers = (intent.getSerializableExtra(EXTRA_HEADERS) as? Map<*, *>)
            ?.entries
            ?.associate { it.key.toString() to it.value.toString() }
            ?: emptyMap()
        channelTitle = intent.getStringExtra(EXTRA_TITLE)
        titleView?.text = channelTitle
            ?.takeIf { it.isNotBlank() }
            ?: "Now Playing"
    }

    private fun buildPlayer(): ExoPlayer {
        return ExoPlayer.Builder(
            this,
            DefaultRenderersFactory(this)
                .setEnableDecoderFallback(true)
                .setMediaCodecSelector(MediaCodecSelector.DEFAULT),
        ).build()
    }

    private fun load(exo: ExoPlayer) {
        if (streamUrl.isEmpty()) {
            showError("No stream URL was provided.")
            return
        }
        val uri = Uri.parse(streamUrl)
        if (!uri.isAbsolute) {
            showError("Invalid stream URL: $streamUrl")
            return
        }
        try {
            val httpDataSourceFactory = buildHttpDataSourceFactory(headers)
            val mediaItem = MediaItem.Builder().setUri(uri).build()
            val mediaSource: MediaSource = when (Util.inferContentType(uri, "")) {
                C.CONTENT_TYPE_HLS -> HlsMediaSource.Factory(httpDataSourceFactory)
                    .createMediaSource(mediaItem)
                C.CONTENT_TYPE_DASH -> DashMediaSource.Factory(httpDataSourceFactory)
                    .createMediaSource(mediaItem)
                C.CONTENT_TYPE_RTSP -> RtspMediaSource.Factory().createMediaSource(mediaItem)
                else -> ProgressiveMediaSource.Factory(httpDataSourceFactory)
                    .createMediaSource(mediaItem)
            }
            loadingSpinner?.visibility = View.VISIBLE
            exo.setMediaSource(mediaSource)
            exo.prepare()
            exo.playWhenReady = true
        } catch (e: Exception) {
            showError("Failed to load stream: ${e.message}")
            emit("onError", mapOf("message" to "Failed to load stream: ${e.message}"))
        }
    }

    private fun buildHttpDataSourceFactory(headers: Map<String, String>): DefaultHttpDataSource.Factory {
        val requestProperties = HashMap<String, String>()
        var userAgent = DEFAULT_USER_AGENT
        headers.forEach { (key, value) ->
            if (key.equals("User-Agent", ignoreCase = true)) {
                userAgent = value
            } else {
                requestProperties[key] = value
            }
        }
        return DefaultHttpDataSource.Factory()
            .setUserAgent(userAgent)
            .setDefaultRequestProperties(requestProperties)
            .setAllowCrossProtocolRedirects(true)
            .setConnectTimeoutMs(CONNECT_TIMEOUT_MS)
            .setReadTimeoutMs(READ_TIMEOUT_MS)
    }

    // ---- Controls -----------------------------------------------------------

    private fun toggleControls() {
        setControlsVisible(!controlsVisible)
    }

    private fun setControlsVisible(visible: Boolean) {
        controlsVisible = visible
        val childCount = root.childCount
        for (i in 0 until childCount) {
            val child = root.getChildAt(i)
            if (child === loadingSpinner) continue
            if (child === errorView) continue
            // The video surface must NEVER be hidden: toggling the overlay
            // controls sets every sibling's visibility, and hiding a SurfaceView
            // blanks the picture (the frames keep being produced but nothing is
            // displayed) while the audio continues.
            if (child === videoSurface) continue
            child.visibility = if (visible) View.VISIBLE else View.GONE
        }
        mainHandler.removeCallbacks(hideControlsRunnable)
        if (visible) {
            mainHandler.postDelayed(hideControlsRunnable, CONTROLS_AUTO_HIDE_MS)
        }
    }

    private fun togglePlayPause() {
        val exo = player ?: return
        if (exo.playWhenReady) {
            exo.pause()
        } else {
            exo.play()
        }
        updatePlayPauseIcon()
    }

    private fun updatePlayPauseIcon() {
        playPauseButton?.text = if (player?.playWhenReady == true) "\u23F8" else "\u25B6"
    }

    private fun showError(message: String) {
        errorView?.text = message
        errorView?.visibility = View.VISIBLE
        playPauseButton?.visibility = View.GONE
    }

    // ---- Flutter events -----------------------------------------------------

    private fun emitPosition() {
        val exo = player ?: return
        if (exo.playbackState == Player.STATE_IDLE) return
        emit(
            "onPosition",
            mapOf(
                "positionMs" to exo.currentPosition,
                "bufferedMs" to exo.bufferedPosition,
                "durationMs" to (if (exo.duration == C.TIME_UNSET) 0L else exo.duration),
            ),
        )
    }

    private fun emit(method: String, arguments: Map<String, Any?>) {
        events?.invokeMethod(method, arguments)
    }

    private fun notifyFinished() {
        if (finishedNotified) return
        finishedNotified = true
        emit("onFinished", mapOf("state" to "stopped"))
    }

    // ---- Transport commands from Dart --------------------------------------

    fun togglePlayPauseCommand() = togglePlayPause()

    fun playCommand() {
        player?.play()
        updatePlayPauseIcon()
    }

    fun pauseCommand() {
        player?.pause()
        updatePlayPauseIcon()
    }

    fun seekTo(positionMs: Long) {
        player?.seekTo(positionMs)
    }

    fun setVolumeCommand(value: Float) {
        volume = value.coerceIn(0f, 1f)
        player?.volume = if (muted) 0f else volume
    }

    fun setMutedCommand(value: Boolean) {
        muted = value
        player?.volume = if (muted) 0f else volume
    }

    fun setSpeed(speed: Float) {
        player?.playbackParameters = PlaybackParameters(speed.coerceIn(0.25f, 4f))
    }

    // ---- Lifecycle ----------------------------------------------------------

    override fun onStart() {
        super.onStart()
        requestAudioFocus()
        mainHandler.post(positionReporter)
    }

    override fun onStop() {
        super.onStop()
        abandonAudioFocus()
        mainHandler.removeCallbacks(positionReporter)
    }

    override fun onDestroy() {
        super.onDestroy()
        if (instance === this) instance = null
        mainHandler.removeCallbacksAndMessages(null)
        player?.removeListener(playerListener)
        player?.release()
        player = null
        notifyFinished()
    }

    private fun requestAudioFocus() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_MEDIA)
            .setContentType(AudioAttributes.CONTENT_TYPE_MOVIE)
            .build()
        val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
            .setAudioAttributes(attributes)
            .setOnAudioFocusChangeListener { }
            .build()
        (getSystemService(Context.AUDIO_SERVICE) as AudioManager)
            .requestAudioFocus(request)
    }

    private fun abandonAudioFocus() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MOVIE)
                    .build(),
            )
            .setOnAudioFocusChangeListener { }
            .build()
        (getSystemService(Context.AUDIO_SERVICE) as AudioManager)
            .abandonAudioFocusRequest(request)
    }
}
