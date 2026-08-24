package com.example.stream_hub

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.SurfaceTexture
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.Surface
import android.view.TextureView
import android.view.View
import android.view.ViewGroup
import android.view.Window
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.SeekBar
import android.widget.TextView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import tv.danmaku.ijk.media.player.IMediaPlayer
import tv.danmaku.ijk.media.player.IjkMediaPlayer
import java.util.HashMap

/**
 * Standalone fullscreen IJKPlayer (FFmpeg) Activity used by the Phase 3
 * playback-engine evaluation (docs/PLAYBACK_ENGINEERING.md §10).
 *
 * Architecture mirrors [NativePlayerActivity] but deliberately scoped down:
 * this backend exists to answer one question — does FFmpeg-based decoding,
 * rendered through a window-owned TextureView outside Flutter's view
 * hierarchy, outperform ExoPlayer/VLC/MediaKit on problem devices?
 *
 * Deliberate omissions versus the production native player:
 * - No EPG drawer / channel zapping (the adapter launches one stream).
 * - No PiP, gestures (brightness/volume/seek swipes) or quality menus.
 * - No automatic fallback: `auto` mode never selects IJK; failures surface
 *   to the PlaybackEngine through the same structured wire format so the
 *   A/B harness records them identically to other engines.
 *
 * Wire protocol (must stay in sync with lib/core/media/player/
 * ijk_player_adapter.dart):
 * - launch channel: stream_hub/ijk_player_launch
 * - events channel: stream_hub/ijk_player_events
 * - events: onState{state}, onPosition{positionMs,bufferedMs,durationMs},
 *   onVideo{width,height}, onError{message,category,httpCode}, onFinished
 */
class IjkPlayerActivity : Activity() {

    companion object {
        const val EXTRA_URL = "extra_stream_url"
        const val EXTRA_HEADERS = "extra_headers"
        const val EXTRA_TITLE = "extra_title"
        const val EXTRA_IS_LIVE = "extra_is_live"

        const val CHANNEL_LAUNCH = "stream_hub/ijk_player_launch"
        const val CHANNEL_EVENTS = "stream_hub/ijk_player_events"

        private const val TAG = "IjkPlayerActivity"
        private const val POSITION_INTERVAL_MS = 500L
        private const val CONTROLS_AUTO_HIDE_MS = 4000L

        // Controlled reconnect budget. IJK surfaces far less error structure
        // than ExoPlayer, so retries are limited to the unambiguous transient
        // class (server-died) until the A/B data justifies a wider policy.
        private const val MAX_RECONNECT_ATTEMPTS = 3
        private const val RECONNECT_BASE_DELAY_MS = 2000L
        private const val RECONNECT_MAX_DELAY_MS = 8000L

        // Grace period between prepared-and-playing and the first rendered
        // frame. Only armed when the stream reports a video track by prepared
        // time, so audio-only channels never trip it.
        private const val RENDER_WATCHDOG_MS = 10000L

        var messenger: BinaryMessenger? = null
        var instance: IjkPlayerActivity? = null

        fun launch(
            context: Context,
            url: String,
            headers: Map<String, String> = emptyMap(),
            title: String? = null,
            isLive: Boolean = false,
        ) {
            val intent = Intent(context, IjkPlayerActivity::class.java).apply {
                putExtra(EXTRA_URL, url)
                putExtra(EXTRA_HEADERS, HashMap(headers))
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_IS_LIVE, isLive)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            context.startActivity(intent)
        }
    }

    private var player: IjkMediaPlayer? = null
    private var events: MethodChannel? = null
    private var volume = 1.0f
    private var muted = false

    private lateinit var root: FrameLayout
    private var videoSurface: TextureView? = null
    private var titleView: TextView? = null
    private var playPauseButton: TextView? = null
    private var currentTimeText: TextView? = null
    private var durationText: TextView? = null
    private var seekBar: SeekBar? = null
    private var loadingSpinner: ProgressBar? = null
    private var errorView: TextView? = null
    private lateinit var controlsOverlay: FrameLayout

    private var controlsVisible = true
    private var finishedNotified = false
    private var isUserTrackingSeek = false

    private var streamUrl: String = ""
    private var headers: Map<String, String> = emptyMap()
    private var channelTitle: String? = null
    private var isLiveIntent = false
    private var pendingPlay = true

    private var reconnectAttempts = 0
    private var reconnectTargetUrl: String? = null
    private var renderedFirstFrame = false

    private var videoWidth = 0
    private var videoHeight = 0

    private lateinit var audioManager: AudioManager
    private var audioFocusRequest: AudioFocusRequest? = null

    private val mainHandler = Handler(Looper.getMainLooper())
    private val hideControlsRunnable = Runnable { setControlsVisible(false) }
    private val reconnectRunnable = Runnable { attemptReconnect() }

    private val renderWatchdogRunnable = Runnable {
        val p = player ?: return@Runnable
        if (isFinishing || isDestroyed) return@Runnable
        if (renderedFirstFrame || !p.isPlaying || !hasVideoTrack()) return@Runnable
        android.util.Log.e(
            TAG,
            "render watchdog: prepared+playing but no video frame rendered within ${RENDER_WATCHDOG_MS}ms " +
                "url=${NativePlaybackDiagnostics.sanitizeUrl(streamUrl)}",
        )
        emitError(
            message = "No video output: player is ready but no frames are rendering.",
            category = NativePlaybackDiagnostics.ErrorCategory.RENDERER.wireName,
            httpCode = null,
        )
    }

    private val positionReporter = object : Runnable {
        override fun run() {
            emitPosition()
            mainHandler.postDelayed(this, POSITION_INTERVAL_MS)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        instance = this
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        setupWindow()

        streamUrl = intent.getStringExtra(EXTRA_URL) ?: ""
        headers = readHeaders(intent)
        channelTitle = intent.getStringExtra(EXTRA_TITLE)
        isLiveIntent = intent.getBooleanExtra(EXTRA_IS_LIVE, false)

        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        buildUi()

        messenger?.let { events = MethodChannel(it, CHANNEL_EVENTS) }
        requestAudioFocus()
        preparePlayer(streamUrl)
    }

    private fun readHeaders(intent: Intent): Map<String, String> {
        @Suppress("DEPRECATION")
        val raw = intent.getSerializableExtra(EXTRA_HEADERS) ?: return emptyMap()
        return (raw as? HashMap<*, *>)
            ?.entries
            ?.associate { it.key.toString() to it.value.toString() }
            ?: emptyMap()
    }

    private fun setupWindow() {
        requestWindowFeature(Window.FEATURE_NO_TITLE)
        window.setFlags(
            WindowManager.LayoutParams.FLAG_FULLSCREEN,
            WindowManager.LayoutParams.FLAG_FULLSCREEN,
        )
        // Let the video render behind cutouts
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.attributes.layoutInDisplayCutoutMode =
                WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
        hideSystemUI()
    }

    private fun hideSystemUI() {
        @Suppress("DEPRECATION")
        window.decorView.systemUiVisibility = (View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_FULLSCREEN)
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            hideSystemUI()
        }
    }

    // -------------------------------------------------------------------------
    // UI construction
    // -------------------------------------------------------------------------

    private fun buildUi() {
        root = FrameLayout(this).apply { setBackgroundColor(android.graphics.Color.BLACK) }

        val texture = TextureView(this)
        texture.surfaceTextureListener = object : TextureView.SurfaceTextureListener {
            override fun onSurfaceTextureAvailable(st: SurfaceTexture, w: Int, h: Int) {
                attachSurfaceIfReady(Surface(st))
            }

            override fun onSurfaceTextureSizeChanged(st: SurfaceTexture, w: Int, h: Int) {
                applyAspectRatioTransform()
            }
            override fun onSurfaceTextureDestroyed(st: SurfaceTexture): Boolean {
                player?.setSurface(null)
                return true
            }

            override fun onSurfaceTextureUpdated(st: SurfaceTexture) {}
        }
        texture.setOnClickListener { toggleControls() }
        root.addView(
            texture,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            ),
        )
        videoSurface = texture

        titleView = TextView(this).apply {
            text = channelTitle
            textSize = 16f
            setTextColor(android.graphics.Color.WHITE)
            setShadowLayer(4f, 0f, 0f, android.graphics.Color.BLACK)
        }
        root.addView(
            titleView,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.TOP or Gravity.START,
            ).apply { setMargins(48, 64, 48, 0) },
        )

        loadingSpinner = ProgressBar(this).apply { visibility = View.VISIBLE }
        root.addView(
            loadingSpinner,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER,
            ),
        )

        errorView = TextView(this).apply {
            visibility = View.GONE
            textSize = 15f
            gravity = Gravity.CENTER
            setTextColor(android.graphics.Color.WHITE)
        }
        root.addView(
            errorView,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER,
            ).apply { setMargins(64, 0, 64, 0) },
        )

        buildControlsOverlay()
        setContentView(root)
        scheduleControlsHide()
    }

    private fun buildControlsOverlay() {
        controlsOverlay = FrameLayout(this)
        val bar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setBackgroundColor(0xAA000000.toInt())
        }

        playPauseButton = TextView(this).apply {
            textSize = 20f
            setTextColor(android.graphics.Color.WHITE)
            setPadding(32, 24, 32, 24)
            text = "\u23F8" // pause glyph; icon updated with state
            setOnClickListener { togglePlayPause() }
        }
        bar.addView(playPauseButton)

        currentTimeText = TextView(this).apply {
            textSize = 13f
            setTextColor(android.graphics.Color.WHITE)
            setPadding(16, 0, 8, 0)
            text = "--:--"
        }
        bar.addView(currentTimeText)

        seekBar = SeekBar(this).apply {
            max = 1000
            setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                override fun onProgressChanged(sb: SeekBar?, progress: Int, fromUser: Boolean) {}

                override fun onStartTrackingTouch(sb: SeekBar?) {
                    isUserTrackingSeek = true
                    scheduleControlsHide()
                }

                override fun onStopTrackingTouch(sb: SeekBar?) {
                    isUserTrackingSeek = false
                    val p = player ?: return
                    val target = (sb!!.progress.toLong() * p.duration) / 1000
                    p.seekTo(target)
                    scheduleControlsHide()
                }
            })
        }
        bar.addView(
            seekBar,
            LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f),
        )

        durationText = TextView(this).apply {
            textSize = 13f
            setTextColor(android.graphics.Color.WHITE)
            setPadding(8, 0, 16, 0)
            text = "--:--"
        }
        bar.addView(durationText)

        controlsOverlay.addView(
            bar,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM,
            ),
        )
        controlsOverlay.setOnClickListener { toggleControls() }
        root.addView(
            controlsOverlay,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            ),
        )
        updatePlayPauseIcon()
    }

    private fun toggleControls() {
        setControlsVisible(!controlsVisible)
    }

    private fun setControlsVisible(visible: Boolean) {
        controlsVisible = visible
        controlsOverlay.visibility = if (visible) View.VISIBLE else View.GONE
        mainHandler.removeCallbacks(hideControlsRunnable)
        if (visible && player?.isPlaying == true) scheduleControlsHide()
    }

    private fun scheduleControlsHide() {
        mainHandler.removeCallbacks(hideControlsRunnable)
        mainHandler.postDelayed(hideControlsRunnable, CONTROLS_AUTO_HIDE_MS)
    }

    private fun updatePlayPauseIcon() {
        val playing = player?.isPlaying == true
        playPauseButton?.text = if (playing) "\u23F8" else "\u25B6"
    }

    private fun togglePlayPause() {
        val p = player ?: return
        if (p.isPlaying) {
            p.pause()
        } else {
            p.start()
        }
        updatePlayPauseIcon()
        scheduleControlsHide()
    }

    // -------------------------------------------------------------------------
    // Player lifecycle
    // -------------------------------------------------------------------------

    private fun attachSurfaceIfReady(surface: Surface) {
        val p = player
        if (p != null) {
            p.setSurface(surface)
        } else {
            pendingSurface = surface
        }
    }

    private var pendingSurface: Surface? = null

    private fun preparePlayer(url: String, resumeAtMs: Long = 0L) {
        if (url.isEmpty()) {
            showError("No stream URL provided.")
            return
        }
        loadingSpinner?.visibility = View.VISIBLE
        errorView?.visibility = View.GONE
        renderedFirstFrame = false

        releasePlayer()

        val p = IjkMediaPlayer()
        try {
            applyOptions(p, isLiveIntent)
            if (headers.isNotEmpty()) {
                val headerString = headers.entries.joinToString("\r\n") { "${it.key}: ${it.value}" } + "\r\n"
                p.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "headers", headerString)
            }
            p.setDataSource(url)
        } catch (e: Exception) {
            android.util.Log.e(TAG, "setDataSource failed url=${NativePlaybackDiagnostics.sanitizeUrl(url)}", e)
            releasePlayerQuietly(p)
            emitError(
                message = "Could not open the stream source.",
                category = NativePlaybackDiagnostics.ErrorCategory.NETWORK.wireName,
                httpCode = null,
            )
            return
        }
        player = p
        pendingSurface?.let { p.setSurface(it) }
        videoSurface?.surfaceTexture?.let { p.setSurface(Surface(it)) }
        p.setOnPreparedListener { mp -> onPrepared(mp, resumeAtMs) }
        p.setOnCompletionListener { onComplete() }
        p.setOnErrorListener { _, what, extra -> onPlayerError(what, extra) }
        p.setOnInfoListener { _, what, extra -> onInfo(what, extra) }
        p.setOnBufferingUpdateListener { _, percent -> bufferedPercent = percent }
        p.setOnSeekCompleteListener { emitPosition() }
        p.setAudioStreamType(AudioManager.STREAM_MUSIC)
        applyVolume()
        emit("onState", mapOf("state" to "loading"))
        p.prepareAsync()
    }

    private var bufferedPercent = 0

    private fun applyOptions(p: IjkMediaPlayer, isLive: Boolean) {
        // Hardware decode via MediaCodec; falls back to soft decode internally
        // when the codec profile is unsupported (FFmpeg handles negotiation).
        p.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "mediacodec", 1)
        p.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "mediacodec-auto-rotate", 1)
        p.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "mediacodec-handle-resolution-change", 1)
        p.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "start-on-prepared", 1)
        p.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "framedrop", 1)
        // Live inputs must not grow unbounded buffers waiting for the app to
        // drain them; keep packet buffering enabled only for VOD-like input.
        p.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "packet-buffering", if (isLive) 0 else 1)
        // Probe limits tuned for IPTV relays: short metadata, long payload.
        p.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "probesize", 5_000_000L)
        p.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "analyzeduration", 3_000_000L)
        p.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "reconnect", 1)
        p.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "reconnect_streamed", 1)
        p.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "rw_timeout", 20_000_000L)
    }

    private fun onPrepared(mp: IMediaPlayer, resumeAtMs: Long) {
        if (reconnectAttempts > 0) {
            android.util.Log.i(TAG, "recovery succeeded after $reconnectAttempts attempt(s)")
            reconnectAttempts = 0
        }
        bufferedPercent = 0
        videoWidth = mp.videoWidth
        videoHeight = mp.videoHeight
        if (resumeAtMs > 0) mp.seekTo(resumeAtMs)
        if (pendingPlay) mp.start()
        loadingSpinner?.visibility = View.GONE
        updatePlayPauseIcon()
        if (videoWidth > 0 && videoHeight > 0) {
            applyAspectRatioTransform()
        }
        emit("onState", mapOf("state" to if (mp.isPlaying) "playing" else "paused"))
        emit("onVideo", mapOf("width" to videoWidth, "height" to videoHeight))
        emitPosition()
        mainHandler.removeCallbacks(positionReporter)
        mainHandler.postDelayed(positionReporter, POSITION_INTERVAL_MS)
        if (hasVideoTrack()) armRenderWatchdog()
    }

    private fun hasVideoTrack(): Boolean =
        videoWidth > 0 || videoHeight > 0

    private fun onInfo(what: Int, extra: Int): Boolean {
        when (what) {
            IMediaPlayer.MEDIA_INFO_VIDEO_RENDERING_START -> {
                mainHandler.removeCallbacks(renderWatchdogRunnable)
                renderedFirstFrame = true
                android.util.Log.i(TAG, "first video frame rendered")
            }
            IMediaPlayer.MEDIA_INFO_BUFFERING_START -> {
                emit("onState", mapOf("state" to "buffering"))
                loadingSpinner?.visibility = View.VISIBLE
            }
            IMediaPlayer.MEDIA_INFO_BUFFERING_END -> {
                emit("onState", mapOf("state" to if (player?.isPlaying == true) "playing" else "paused"))
                loadingSpinner?.visibility = View.GONE
            }
        }
        return false
    }

    private fun onComplete() {
        mainHandler.removeCallbacks(renderWatchdogRunnable)
        mainHandler.removeCallbacks(positionReporter)
        loadingSpinner?.visibility = View.GONE
        emit("onState", mapOf("state" to "completed"))
    }

    /**
     * Returns true when handled internally (controlled reconnect scheduled);
     * false when the failure is surfaced to Flutter as a terminal error.
     */
    private fun onPlayerError(what: Int, extra: Int): Boolean {
        loadingSpinner?.visibility = View.GONE
        mainHandler.removeCallbacks(reconnectRunnable)
        mainHandler.removeCallbacks(renderWatchdogRunnable)
        mainHandler.removeCallbacks(positionReporter)

        val classification = classifyIjkError(what)
        android.util.Log.e(
            TAG,
            "playback error category=${classification.category.wireName} " +
                "httpCode=${classification.httpCode} what=$what extra=$extra " +
                "url=${NativePlaybackDiagnostics.sanitizeUrl(streamUrl)}: ${classification.friendlyMessage}",
        )

        if (what == IMediaPlayer.MEDIA_ERROR_SERVER_DIED) {
            scheduleReconnect(classification)
            return true
        }
        emitError(classification.friendlyMessage, classification.category.wireName, classification.httpCode)
        return true
    }

    /**
     * IJK exposes two coarse codes plus FFmpeg errno payloads in [extra].
     * Classification stays conservative: only server-died is treated as
     * transient; everything else maps through [NativePlaybackDiagnostics]
     * categories with UNKNOWN defaults rather than guessing retryability.
     */
    private fun classifyIjkError(what: Int): NativePlaybackDiagnostics.Classification {
        return when (what) {
            IMediaPlayer.MEDIA_ERROR_SERVER_DIED -> NativePlaybackDiagnostics.Classification(
                category = NativePlaybackDiagnostics.ErrorCategory.SERVER,
                httpCode = null,
                friendlyMessage = "The stream server stopped responding.",
            )
            -10000 -> NativePlaybackDiagnostics.Classification(
                category = NativePlaybackDiagnostics.ErrorCategory.NETWORK,
                httpCode = null,
                friendlyMessage = "Network interrupted while streaming.",
            )
            else -> NativePlaybackDiagnostics.Classification(
                category = NativePlaybackDiagnostics.ErrorCategory.UNKNOWN,
                httpCode = null,
                friendlyMessage = "Playback failed. Try another engine for this stream.",
            )
        }
    }

    // -------------------------------------------------------------------------
    // Controlled reconnect
    // -------------------------------------------------------------------------

    private fun scheduleReconnect(classification: NativePlaybackDiagnostics.Classification) {
        if (reconnectAttempts >= MAX_RECONNECT_ATTEMPTS) {
            android.util.Log.e(TAG, "giving up after $MAX_RECONNECT_ATTEMPTS reconnect attempts")
            emitError(classification.friendlyMessage, classification.category.wireName, classification.httpCode)
            return
        }
        val delay = (RECONNECT_BASE_DELAY_MS shl reconnectAttempts.coerceAtMost(4))
            .coerceAtMost(RECONNECT_MAX_DELAY_MS)
        reconnectAttempts++
        reconnectTargetUrl = streamUrl
        android.util.Log.w(TAG, "scheduling reconnect #$reconnectAttempts in ${delay}ms")
        loadingSpinner?.visibility = View.VISIBLE
        emit("onState", mapOf("state" to "buffering"))
        mainHandler.postDelayed(reconnectRunnable, delay)
    }

    private fun attemptReconnect() {
        if (isFinishing || isDestroyed) return
        if (reconnectTargetUrl != streamUrl) return
        preparePlayer(streamUrl)
    }

    private fun armRenderWatchdog() {
        mainHandler.removeCallbacks(renderWatchdogRunnable)
        mainHandler.postDelayed(renderWatchdogRunnable, RENDER_WATCHDOG_MS)
    }

    // -------------------------------------------------------------------------
    // Commands from Flutter (stream_hub/ijk_player_launch)
    // -------------------------------------------------------------------------

    fun loadStream(url: String, newHeaders: Map<String, String>, title: String?, isLive: Boolean) {
        streamUrl = url
        headers = newHeaders
        channelTitle = title
        isLiveIntent = isLive
        reconnectAttempts = 0
        reconnectTargetUrl = null
        titleView?.text = title
        preparePlayer(url)
    }

    fun reloadCommand() {
        preparePlayer(streamUrl)
    }

    fun playCommand() {
        pendingPlay = true
        player?.start()
        updatePlayPauseIcon()
    }

    fun pauseCommand() {
        pendingPlay = false
        player?.pause()
        updatePlayPauseIcon()
    }

    fun stopCommand() {
        finish()
    }

    fun seekTo(ms: Long) {
        player?.seekTo(ms)
    }

    fun setVolumeCommand(v: Float) {
        volume = v.coerceIn(0f, 1f)
        applyVolume()
    }

    fun setMutedCommand(m: Boolean) {
        muted = m
        applyVolume()
    }

    fun setSpeedCommand(speed: Float) {
        player?.setSpeed(speed.coerceIn(0.25f, 4.0f))
    }

    private fun applyVolume() {
        val left = if (muted) 0f else volume
        val right = if (muted) 0f else volume
        player?.setVolume(left, right)
    }

    // -------------------------------------------------------------------------
    // Position reporting & aspect ratio
    // -------------------------------------------------------------------------

    private fun emitPosition() {
        val p = player ?: return
        val positionMs = p.currentPosition.coerceAtLeast(0L)
        val durationMs = if (p.duration > 0) p.duration else 0L
        val bufferedMs = if (durationMs > 0) {
            ((bufferedPercent.coerceIn(0, 100) * durationMs) / 100)
        } else {
            0L
        }
        currentTimeText?.text = formatMs(positionMs)
        durationText?.text = formatMs(durationMs)
        if (!isUserTrackingSeek && durationMs > 0) {
            seekBar?.progress = ((positionMs * 1000) / durationMs).toInt().coerceIn(0, 1000)
        }
        emit(
            "onPosition",
            mapOf(
                "positionMs" to positionMs,
                "bufferedMs" to bufferedMs,
                "durationMs" to durationMs,
            ),
        )
    }

    /** Letterbox-fits the TextureView content to the decoded video size. */
    private fun applyAspectRatioTransform() {
        val view = videoSurface ?: return
        val vw = videoWidth
        val vh = videoHeight
        if (vw <= 0 || vh <= 0) return
        val viewW = view.width.toFloat()
        val viewH = view.height.toFloat()
        if (viewW <= 0f || viewH <= 0f) return

        val matrix = android.graphics.Matrix()
        view.getTransform(matrix)

        // Find the scale to fit the video to the view while keeping aspect ratio (FIT_CENTER)
        val scaleX = viewW / vw
        val scaleY = viewH / vh
        val scale = Math.min(scaleX, scaleY)

        val renderW = vw * scale
        val renderH = vh * scale

        // TextureView stretches the video to viewW x viewH by default.
        // We shrink it back to renderW x renderH so it isn't distorted.
        val sx = renderW / viewW
        val sy = renderH / viewH

        matrix.setScale(sx, sy, viewW / 2f, viewH / 2f)
        view.setTransform(matrix)
    }

    private fun formatMs(ms: Long): String {
        val totalSeconds = ms / 1000
        val h = totalSeconds / 3600
        val m = (totalSeconds % 3600) / 60
        val s = totalSeconds % 60
        return if (h > 0) "%d:%02d:%02d".format(h, m, s) else "%02d:%02d".format(m, s)
    }

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    private fun emit(method: String, args: Map<String, Any?>) {
        events?.invokeMethod(method, args)
    }

    private fun emitError(message: String, category: String?, httpCode: Int?) {
        emit(
            "onError",
            mapOf(
                "message" to message,
                "category" to category,
                "httpCode" to httpCode,
            ),
        )
    }

    private fun notifyFinishedOnce() {
        if (finishedNotified) return
        finishedNotified = true
        emit("onFinished", mapOf<String, Any?>())
    }

    private fun showError(message: String) {
        loadingSpinner?.visibility = View.GONE
        errorView?.visibility = View.VISIBLE
        errorView?.text = message
    }

    // -------------------------------------------------------------------------
    // Audio focus
    // -------------------------------------------------------------------------

    private fun requestAudioFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MOVIE)
                        .build(),
                )
                .build()
            audioFocusRequest = request
            audioManager.requestAudioFocus(request)
        } else {
            @Suppress("DEPRECATION")
            audioManager.requestAudioFocus(null, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN)
        }
    }

    private fun abandonAudioFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioFocusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
        } else {
            @Suppress("DEPRECATION")
            audioManager.abandonAudioFocus(null)
        }
    }

    // -------------------------------------------------------------------------
    // Teardown
    // -------------------------------------------------------------------------

    private fun releasePlayer() {
        mainHandler.removeCallbacks(positionReporter)
        val p = player
        player = null
        if (p != null) {
            try {
                p.stop()
            } catch (_: Exception) {}
            p.release()
        }
    }

    private fun releasePlayerQuietly(p: IjkMediaPlayer) {
        try {
            p.release()
        } catch (_: Exception) {}
    }

    override fun onDestroy() {
        super.onDestroy()
        mainHandler.removeCallbacksAndMessages(null)
        releasePlayer()
        abandonAudioFocus()
        notifyFinishedOnce()
        instance = null
        pendingSurface?.release()
        pendingSurface = null
    }
}
