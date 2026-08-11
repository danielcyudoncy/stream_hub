package com.example.stream_hub

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
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
import android.widget.ImageView
import android.widget.ProgressBar
import android.widget.TextView
import androidx.annotation.OptIn
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.Player
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
 * its content view. The video is a regular Android view composited by the
 * Android view system with no Flutter involvement at all, which is the only
 * path that has proven able to display video on the itel C671L (Unisoc ums9230/Mali).
 * TextureView is used instead of SurfaceView to avoid a known MediaCodec
 * `setOutputSurface` bug (BAD_INDEX) that occurs on this device class when the
 * surface is recreated during playback.
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
        private const val CHANNEL_EVENTS = "stream_hub/native_player_events"
        private const val CHANNEL_LAUNCH = "stream_hub/native_player_launch"
        private const val DEFAULT_USER_AGENT = "StreamHubPro/1.0 (Android)"
        private const val CONNECT_TIMEOUT_MS = 15_000
        private const val READ_TIMEOUT_MS = 15_000
        private const val POSITION_INTERVAL_MS = 500L
        private const val CONTROLS_AUTO_HIDE_MS = 4_000L

        /** Messenger of the live Flutter engine, set by [MainActivity]. */
        @Volatile
        var messenger: BinaryMessenger? = null

        /** The currently visible native player, if any. */
        @Volatile
        var instance: NativePlayerActivity? = null

        /** Launches the native player for [url] with [headers]. */
        fun launch(context: Context, url: String, headers: Map<String, String>) {
            val intent = Intent(context, NativePlayerActivity::class.java)
                .putExtra(EXTRA_URL, url)
                .putExtra(EXTRA_HEADERS, HashMap(headers))
            context.startActivity(intent)
        }
    }

    private var player: ExoPlayer? = null
    private var events: MethodChannel? = null
    private var volume = 1.0f
    private var muted = false

    private lateinit var root: FrameLayout
    private var videoSurface: TextureView? = null
    private var playPauseButton: TextView? = null
    private var loadingSpinner: ProgressBar? = null
    private var errorView: TextView? = null
    private var controlsVisible = true
    private var finishedNotified = false

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
                    emit("onState", mapOf("state" to if (player?.playWhenReady == true) "playing" else "paused"))
                    emitPosition()
                }
                Player.STATE_ENDED -> emit("onState", mapOf("state" to "completed"))
                Player.STATE_IDLE -> Unit
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
        setupUi()
        parseIntent()

        val exo = buildPlayer()
        player = exo
        val textureView = TextureView(this)
        videoSurface = textureView
        textureView.setOnClickListener { toggleControls() }
        root.setOnClickListener { toggleControls() }
        root.addView(
            textureView,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            ),
        )
        exo.setVideoTextureView(textureView)
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
        // Opaque black window background is required on Unisoc/Mali devices:
        // transparent windows break video surface compositing there.
        window.setBackgroundDrawable(ColorDrawable(Color.BLACK))
    }

    private fun setupUi() {
        root = FrameLayout(this)

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

        // Top-left back button.
        val backButton = TextView(this).apply {
            text = "\u2715"
            textSize = 28f
            setTextColor(android.graphics.Color.WHITE)
            gravity = Gravity.CENTER
            setPadding(24, 24, 24, 24)
            setOnClickListener { finish() }
        }
        root.addView(
            backButton,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.TOP or Gravity.START,
            ),
        )

        // Bottom-center play/pause button.
        playPauseButton = TextView(this).apply {
            textSize = 40f
            setTextColor(android.graphics.Color.WHITE)
            gravity = Gravity.CENTER
            setPadding(32, 32, 32, 32)
            setOnClickListener { togglePlayPause() }
        }
        root.addView(
            playPauseButton,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL,
            ),
        )
        updatePlayPauseIcon()

        setContentView(root)
        setControlsVisible(true)
    }

    private var streamUrl: String = ""
    private var headers: Map<String, String> = emptyMap()

    private fun parseIntent() {
        streamUrl = intent.getStringExtra(EXTRA_URL) ?: ""
        headers = (intent.getSerializableExtra(EXTRA_HEADERS) as? Map<*, *>)
            ?.entries
            ?.associate { it.key.toString() to it.value.toString() }
            ?: emptyMap()
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
            // controls sets every sibling's visibility, and hiding a video
            // surface blanks the picture (the frames keep being produced but
            // nothing is displayed) while the audio continues.
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

    private var wasPlayingBeforePause = false

    override fun onStart() {
        super.onStart()
        requestAudioFocus()
        mainHandler.post(positionReporter)
    }

    override fun onResume() {
        super.onResume()
        if (wasPlayingBeforePause) {
            player?.play()
            wasPlayingBeforePause = false
        }
    }

    override fun onPause() {
        super.onPause()
        player?.let { exo ->
            wasPlayingBeforePause = exo.playWhenReady
            exo.pause()
        }
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
