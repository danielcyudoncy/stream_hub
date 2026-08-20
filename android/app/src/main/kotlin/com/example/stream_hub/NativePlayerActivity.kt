package com.example.stream_hub

import android.app.Activity
import android.app.AlertDialog
import android.app.PictureInPictureParams
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.SurfaceTexture
import android.graphics.Typeface
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
import android.text.Editable
import android.text.TextWatcher
import android.util.Rational
import android.view.GestureDetector
import android.view.Gravity
import android.view.MotionEvent
import android.view.TextureView
import android.view.View
import android.view.ViewGroup
import android.view.Window
import android.view.WindowManager
import android.widget.BaseAdapter
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.HorizontalScrollView
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ListView
import android.widget.ProgressBar
import android.widget.SeekBar
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
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector
import androidx.media3.extractor.DefaultExtractorsFactory
import androidx.media3.extractor.ts.DefaultTsPayloadReaderFactory
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.Serializable
import kotlin.math.abs

/**
 * Aspect ratio display mode options.
 */
enum class AspectRatioMode {
    FIT,
    ZOOM,
    STRETCH,
    SIXTEEN_NINE,
    FOUR_THREE,
}

/**
 * Normalized channel item passed from Flutter to native player.
 */
data class NativeChannelItem(
    val id: String,
    val name: String,
    val url: String,
    val logoUrl: String? = null,
    val epgTitle: String? = null,
    val category: String? = null,
    val headers: Map<String, String> = emptyMap(),
) : Serializable

/**
 * Standalone fullscreen ExoPlayer Activity with gesture controls, PiP,
 * quick EPG drawer, and responsive player HUD for all screen orientations.
 */
@OptIn(UnstableApi::class)
class NativePlayerActivity : Activity() {

    companion object {
        const val EXTRA_URL = "extra_stream_url"
        const val EXTRA_HEADERS = "extra_headers"
        const val EXTRA_TITLE = "extra_title"
        const val EXTRA_CHANNELS = "extra_channels"
        const val EXTRA_CHANNEL_INDEX = "extra_channel_index"
        const val EXTRA_IS_LIVE = "extra_is_live"

        const val CHANNEL_LAUNCH = "stream_hub/native_player_launch"
        const val CHANNEL_EVENTS = "stream_hub/native_player_events"

        private const val DEFAULT_USER_AGENT = "IPTVSmarters/1.0 (Linux; Android)"
        private const val CONNECT_TIMEOUT_MS = 15000
        private const val READ_TIMEOUT_MS = 20000
        private const val POSITION_INTERVAL_MS = 500L
        private const val CONTROLS_AUTO_HIDE_MS = 4000L
        private const val SEEK_STEP_MS = 10000L

        var messenger: BinaryMessenger? = null
        var instance: NativePlayerActivity? = null

        var channelList: List<NativeChannelItem> = emptyList()
        var currentChannelIndex: Int = -1

        fun launch(
            context: Context,
            url: String,
            headers: Map<String, String> = emptyMap(),
            title: String? = null,
            channels: List<NativeChannelItem>? = null,
            channelIndex: Int = -1,
            isLive: Boolean = false,
        ) {
            channels?.let { channelList = it }
            if (channelIndex >= 0) currentChannelIndex = channelIndex

            val intent = Intent(context, NativePlayerActivity::class.java).apply {
                putExtra(EXTRA_URL, url)
                putExtra(EXTRA_HEADERS, HashMap(headers))
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_CHANNEL_INDEX, channelIndex)
                putExtra(EXTRA_IS_LIVE, isLive)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
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
    private var subtitleEpgView: TextView? = null
    private var playPauseButton: TextView? = null
    private var rewindButton: TextView? = null
    private var forwardButton: TextView? = null
    private var qualityButton: TextView? = null
    private var aspectRatioButton: TextView? = null
    private var speedButton: TextView? = null
    private var currentTimeText: TextView? = null
    private var durationText: TextView? = null
    private var seekBar: SeekBar? = null
    private var isUserTrackingSeek = false

    private var loadingSpinner: ProgressBar? = null
    private var errorView: TextView? = null

    // Overlay containers
    private lateinit var controlsOverlay: FrameLayout
    private lateinit var hudOverlay: FrameLayout
    private lateinit var brightnessHud: LinearLayout
    private lateinit var brightnessProgressBar: ProgressBar
    private lateinit var brightnessText: TextView
    private lateinit var volumeHud: LinearLayout
    private lateinit var volumeProgressBar: ProgressBar
    private lateinit var volumeText: TextView
    private lateinit var seekHud: LinearLayout
    private lateinit var seekText: TextView
    private lateinit var doubleTapLeftFeedback: TextView
    private lateinit var doubleTapRightFeedback: TextView

    // EPG / Channel & Category Drawer
    private lateinit var epgDrawer: FrameLayout
    private lateinit var channelListView: ListView
    private var channelListTitleView: TextView? = null
    private var channelCountBadge: TextView? = null
    private var categoryChipsContainer: LinearLayout? = null
    private var searchEditText: EditText? = null
    private var emptyStateView: TextView? = null
    private var isEpgDrawerOpen = false

    private var allCategories: List<String> = listOf("All Channels")
    private var selectedCategory: String = "All Channels"
    private var searchQuery: String = ""
    private val displayedChannels: MutableList<NativeChannelItem> = mutableListOf()

    private var controlsVisible = true
    private var finishedNotified = false
    private var selectedQuality: Int? = null
    private var currentAspectRatio = AspectRatioMode.SIXTEEN_NINE
    private var userSelectedAspectRatio = false
    private var currentSpeed = 1.0f

    private var streamUrl: String = ""
    private var headers: Map<String, String> = emptyMap()
    private var channelTitle: String? = null
    private var isLiveIntent = false

    val isLiveStream: Boolean
        get() = isLiveIntent || (player?.isCurrentMediaItemLive == true) || (player?.duration == C.TIME_UNSET) || ((player?.duration ?: 0L) <= 0L)

    private var videoWidth = 0
    private var videoHeight = 0

    private val mainHandler = Handler(Looper.getMainLooper())
    private val hideControlsRunnable = Runnable { setControlsVisible(false) }
    private val hideHudRunnable = Runnable { hideAllHuds() }

    private lateinit var audioManager: AudioManager
    private lateinit var gestureDetector: GestureDetector

    // Touch gesture tracking state
    private var touchStartX = 0f
    private var touchStartY = 0f
    private var isDraggingBrightness = false
    private var isDraggingVolume = false
    private var isDraggingSeek = false
    private var initialVolume = 0
    private var initialBrightness = 0.5f
    private var initialPositionMs = 0L
    private var seekDeltaMs = 0L

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
                videoWidth = videoSize.width
                videoHeight = videoSize.height
                applyAspectRatioTransform()
                emit("onVideo", mapOf("width" to videoSize.width, "height" to videoSize.height))
            }
        }

        override fun onPlayerError(error: PlaybackException) {
            loadingSpinner?.visibility = View.GONE
            val cause = error.cause
            val httpCode = if (cause is androidx.media3.datasource.HttpDataSource.InvalidResponseCodeException) {
                cause.responseCode
            } else null

            val friendlyMsg = when {
                httpCode == 401 || httpCode == 403 ->
                    "Access denied (HTTP $httpCode): Stream link expired or invalid credentials."
                httpCode == 404 ->
                    "Stream not found (HTTP 404): Channel stream may be offline."
                httpCode != null && httpCode >= 500 ->
                    "Server error (HTTP $httpCode): Stream unavailable or connection limit exceeded."
                error.errorCode == PlaybackException.ERROR_CODE_IO_NETWORK_CONNECTION_FAILED ||
                error.errorCode == PlaybackException.ERROR_CODE_IO_NETWORK_CONNECTION_TIMEOUT ->
                    "Network error: Unable to connect to stream server."
                error.errorCode == PlaybackException.ERROR_CODE_IO_BAD_HTTP_STATUS ->
                    "Server error: Stream unavailable or connection limit exceeded."
                error.errorCode == PlaybackException.ERROR_CODE_PARSING_CONTAINER_UNSUPPORTED ||
                error.errorCode == PlaybackException.ERROR_CODE_PARSING_CONTAINER_MALFORMED ->
                    "Stream format or codec unsupported."
                else -> "${error.errorCodeName}: ${error.message}"
            }
            android.util.Log.e("NativePlayerActivity", "ExoPlayer playback error on $streamUrl (code=${error.errorCode}, httpCode=$httpCode): $friendlyMsg", error)
            showError(friendlyMsg)
            emit("onError", mapOf("message" to friendlyMsg))
        }
    }

    private fun dp(value: Int): Int {
        return (value * resources.displayMetrics.density).toInt()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        instance = this
        events = messenger?.let { MethodChannel(it, CHANNEL_EVENTS) }
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager

        setupWindow()
        root = FrameLayout(this).apply {
            setBackgroundColor(Color.BLACK)
        }

        val isLandscape = resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE
        currentAspectRatio = if (isLandscape) AspectRatioMode.ZOOM else AspectRatioMode.SIXTEEN_NINE

        val exo = buildPlayer()
        player = exo
        val textureView = TextureView(this).apply {
            surfaceTextureListener = object : TextureView.SurfaceTextureListener {
                override fun onSurfaceTextureAvailable(surface: SurfaceTexture, width: Int, height: Int) {
                    applyAspectRatioTransform()
                }
                override fun onSurfaceTextureSizeChanged(surface: SurfaceTexture, width: Int, height: Int) {
                    applyAspectRatioTransform()
                }
                override fun onSurfaceTextureDestroyed(surface: SurfaceTexture): Boolean = true
                override fun onSurfaceTextureUpdated(surface: SurfaceTexture) {}
            }
        }
        videoSurface = textureView
        exo.setVideoTextureView(textureView)

        root.addView(
            textureView,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
                Gravity.CENTER,
            ),
        )

        parseIntent()
        setupGestures()
        setupHudOverlay()
        setupUi()
        setupEpgDrawer()

        exo.addListener(playerListener)
        loadStream(streamUrl, headers, channelTitle)
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        if (!userSelectedAspectRatio) {
            if (newConfig.orientation == Configuration.ORIENTATION_LANDSCAPE) {
                currentAspectRatio = AspectRatioMode.ZOOM
                aspectRatioButton?.text = "Zoom"
            } else if (newConfig.orientation == Configuration.ORIENTATION_PORTRAIT) {
                currentAspectRatio = AspectRatioMode.SIXTEEN_NINE
                aspectRatioButton?.text = "16:9"
            }
        }
        applyImmersiveMode()
        root.post {
            applyAspectRatioTransform()
        }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            applyImmersiveMode()
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        parseIntent()
        loadStream(streamUrl, headers, channelTitle)
        runOnUiThread {
            (channelListView.adapter as? BaseAdapter)?.notifyDataSetChanged()
        }
    }

    fun updateChannels(channels: List<NativeChannelItem>?, currentIndex: Int) {
        channels?.let { channelList = it }
        if (currentIndex >= 0) currentChannelIndex = currentIndex
        runOnUiThread {
            rebuildCategoriesAndFilter()
            if (::channelListView.isInitialized && channelList.isNotEmpty() && currentChannelIndex in channelList.indices) {
                val currentInDisplayed = displayedChannels.indexOfFirst {
                    it.id == channelList[currentChannelIndex].id
                }
                if (currentInDisplayed >= 0) {
                    channelListView.setSelection(currentInDisplayed)
                }
            }
        }
    }

    private fun setupWindow() {
        try {
            requestWindowFeature(Window.FEATURE_NO_TITLE)
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                window.attributes = window.attributes.apply {
                    layoutInDisplayCutoutMode =
                        WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
                }
            }
            window.setFlags(
                WindowManager.LayoutParams.FLAG_FULLSCREEN,
                WindowManager.LayoutParams.FLAG_FULLSCREEN,
            )
            window.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
        } catch (_: Throwable) {}
    }

    private fun applyImmersiveMode() {
        try {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility =
                (View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                    or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                    or View.SYSTEM_UI_FLAG_FULLSCREEN
                    or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                    or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                    or View.SYSTEM_UI_FLAG_LAYOUT_STABLE)
        } catch (_: Throwable) {}
    }

    private fun setupGestures() {
        gestureDetector = GestureDetector(this, object : GestureDetector.SimpleOnGestureListener() {
            override fun onSingleTapConfirmed(e: MotionEvent): Boolean {
                if (isEpgDrawerOpen) {
                    closeEpgDrawer()
                } else {
                    toggleControls()
                }
                return true
            }

            override fun onDoubleTap(e: MotionEvent): Boolean {
                // Live TV broadcasts do not support relative seeking or double-tap skip
                if (isLiveStream) {
                    return false
                }

                val width = root.width
                if (width <= 0) return false
                if (e.x < width / 2) {
                    seekRelative(-SEEK_STEP_MS)
                    showDoubleTapFeedback(isLeft = true)
                } else {
                    seekRelative(SEEK_STEP_MS)
                    showDoubleTapFeedback(isLeft = false)
                }
                return true
            }
        })
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (isEpgDrawerOpen) {
            return super.onTouchEvent(event)
        }

        if (gestureDetector.onTouchEvent(event)) {
            return true
        }

        val width = root.width.toFloat().coerceAtLeast(1f)
        val height = root.height.toFloat().coerceAtLeast(1f)

        when (event.action) {
            MotionEvent.ACTION_DOWN -> {
                touchStartX = event.x
                touchStartY = event.y
                isDraggingBrightness = false
                isDraggingVolume = false
                isDraggingSeek = false
                initialVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
                initialBrightness = window.attributes.screenBrightness.let {
                    if (it < 0f) 0.5f else it
                }
                initialPositionMs = player?.currentPosition ?: 0L
                seekDeltaMs = 0L
            }
            MotionEvent.ACTION_MOVE -> {
                val deltaX = event.x - touchStartX
                val deltaY = touchStartY - event.y // upwards is positive

                if (!isDraggingBrightness && !isDraggingVolume && !isDraggingSeek) {
                    if (abs(deltaY) > dp(16) && abs(deltaY) > abs(deltaX)) {
                        if (touchStartX < width / 2) {
                            isDraggingBrightness = true
                        } else {
                            isDraggingVolume = true
                        }
                    } else if (!isLiveStream && abs(deltaX) > dp(20) && abs(deltaX) > abs(deltaY)) {
                        // Touch scrubbing is only allowed for VOD (Movies / Series), NOT Live TV
                        isDraggingSeek = true
                    }
                }

                if (isDraggingBrightness) {
                    val deltaRatio = deltaY / (height * 0.75f)
                    val newBrightness = (initialBrightness + deltaRatio).coerceIn(0.01f, 1.0f)
                    val lp = window.attributes
                    lp.screenBrightness = newBrightness
                    window.attributes = lp
                    showBrightnessHud((newBrightness * 100).toInt())
                } else if (isDraggingVolume) {
                    val maxVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC).coerceAtLeast(1)
                    val deltaVol = ((deltaY / (height * 0.75f)) * maxVol).toInt()
                    val newVol = (initialVolume + deltaVol).coerceIn(0, maxVol)
                    audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, newVol, 0)
                    val percent = (newVol.toFloat() / maxVol * 100).toInt()
                    showVolumeHud(percent)
                } else if (isDraggingSeek && !isLiveStream) {
                    val exo = player
                    if (exo != null) {
                        val duration = if (exo.duration == C.TIME_UNSET) 0L else exo.duration
                        val scrubRangeMs = if (duration > 0) 120_000L else 60_000L
                        seekDeltaMs = ((deltaX / width) * scrubRangeMs).toLong()
                        val targetMs = (initialPositionMs + seekDeltaMs).coerceAtLeast(0L)
                        showSeekHud(seekDeltaMs, targetMs, duration)
                    }
                }
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                if (isDraggingSeek && !isLiveStream && seekDeltaMs != 0L) {
                    val targetMs = (initialPositionMs + seekDeltaMs).coerceAtLeast(0L)
                    player?.seekTo(targetMs)
                }
                isDraggingBrightness = false
                isDraggingVolume = false
                isDraggingSeek = false
                mainHandler.postDelayed(hideHudRunnable, 1000L)
            }
        }
        return true
    }

    private fun setupHudOverlay() {
        hudOverlay = FrameLayout(this)

        // Brightness HUD
        brightnessHud = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(20), dp(16), dp(20), dp(16))
            background = GradientDrawable().apply {
                setColor(0xCC1E1E1E.toInt())
                cornerRadius = dp(16).toFloat()
            }
            visibility = View.GONE
        }
        val brightIcon = TextView(this).apply {
            text = "☀ Brightness"
            textSize = 14f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
        }
        brightnessProgressBar = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            max = 100
        }
        brightnessText = TextView(this).apply {
            textSize = 13f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
        }
        brightnessHud.addView(brightIcon)
        brightnessHud.addView(
            brightnessProgressBar,
            LinearLayout.LayoutParams(dp(120), ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                topMargin = dp(8)
                bottomMargin = dp(4)
            },
        )
        brightnessHud.addView(brightnessText)

        // Volume HUD
        volumeHud = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(20), dp(16), dp(20), dp(16))
            background = GradientDrawable().apply {
                setColor(0xCC1E1E1E.toInt())
                cornerRadius = dp(16).toFloat()
            }
            visibility = View.GONE
        }
        val volIcon = TextView(this).apply {
            text = "\uD83D\uDD0A Volume"
            textSize = 14f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
        }
        volumeProgressBar = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            max = 100
        }
        volumeText = TextView(this).apply {
            textSize = 13f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
        }
        volumeHud.addView(volIcon)
        volumeHud.addView(
            volumeProgressBar,
            LinearLayout.LayoutParams(dp(120), ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                topMargin = dp(8)
                bottomMargin = dp(4)
            },
        )
        volumeHud.addView(volumeText)

        // Seek HUD
        seekHud = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(24), dp(14), dp(24), dp(14))
            background = GradientDrawable().apply {
                setColor(0xCC1E1E1E.toInt())
                cornerRadius = dp(16).toFloat()
            }
            visibility = View.GONE
        }
        seekText = TextView(this).apply {
            textSize = 14f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
        }
        seekHud.addView(seekText)

        // Double Tap Feedback Left / Right
        doubleTapLeftFeedback = TextView(this).apply {
            text = "⏪ 10s"
            textSize = 16f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            setPadding(dp(16), dp(10), dp(16), dp(10))
            background = GradientDrawable().apply {
                setColor(0xAA000000.toInt())
                cornerRadius = dp(20).toFloat()
            }
            visibility = View.GONE
        }
        doubleTapRightFeedback = TextView(this).apply {
            text = "10s ⏩"
            textSize = 16f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            setPadding(dp(16), dp(10), dp(16), dp(10))
            background = GradientDrawable().apply {
                setColor(0xAA000000.toInt())
                cornerRadius = dp(20).toFloat()
            }
            visibility = View.GONE
        }

        hudOverlay.addView(
            brightnessHud,
            FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.CENTER),
        )
        hudOverlay.addView(
            volumeHud,
            FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.CENTER),
        )
        hudOverlay.addView(
            seekHud,
            FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.CENTER),
        )
        hudOverlay.addView(
            doubleTapLeftFeedback,
            FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.CENTER_VERTICAL or Gravity.START).apply {
                leftMargin = dp(40)
            },
        )
        hudOverlay.addView(
            doubleTapRightFeedback,
            FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.CENTER_VERTICAL or Gravity.END).apply {
                rightMargin = dp(40)
            },
        )

        root.addView(
            hudOverlay,
            FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT),
        )
    }

    private fun showBrightnessHud(percent: Int) {
        hideAllHuds()
        brightnessProgressBar.progress = percent
        brightnessText.text = "$percent%"
        brightnessHud.visibility = View.VISIBLE
    }

    private fun showVolumeHud(percent: Int) {
        hideAllHuds()
        volumeProgressBar.progress = percent
        volumeText.text = "$percent%"
        volumeHud.visibility = View.VISIBLE
    }

    private fun showSeekHud(deltaMs: Long, targetMs: Long, durationMs: Long) {
        hideAllHuds()
        val sign = if (deltaMs >= 0) "+" else ""
        val deltaSec = (deltaMs / 1000).toInt()
        val targetFormatted = formatTime(targetMs)
        val durationFormatted = if (durationMs > 0) " / ${formatTime(durationMs)}" else " (Live)"
        seekText.text = "$sign${deltaSec}s\n$targetFormatted$durationFormatted"
        seekHud.visibility = View.VISIBLE
    }

    private fun showDoubleTapFeedback(isLeft: Boolean) {
        hideAllHuds()
        val target = if (isLeft) doubleTapLeftFeedback else doubleTapRightFeedback
        target.visibility = View.VISIBLE
        mainHandler.postDelayed({ target.visibility = View.GONE }, 700L)
    }

    private fun hideAllHuds() {
        brightnessHud.visibility = View.GONE
        volumeHud.visibility = View.GONE
        seekHud.visibility = View.GONE
        doubleTapLeftFeedback.visibility = View.GONE
        doubleTapRightFeedback.visibility = View.GONE
    }

    private fun formatTime(ms: Long): String {
        val totalSec = ms / 1000
        val s = totalSec % 60
        val m = (totalSec / 60) % 60
        val h = totalSec / 3600
        return if (h > 0) String.format("%d:%02d:%02d", h, m, s) else String.format("%02d:%02d", m, s)
    }

    private fun setupUi() {
        controlsOverlay = FrameLayout(this)

        loadingSpinner = ProgressBar(this, null, android.R.attr.progressBarStyleLarge).apply {
            visibility = View.GONE
        }
        controlsOverlay.addView(
            loadingSpinner,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER,
            ),
        )

        errorView = TextView(this).apply {
            textSize = 14f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            visibility = View.GONE
            setPadding(dp(20), dp(12), dp(20), dp(12))
            background = GradientDrawable().apply {
                setColor(0xCCB00020.toInt())
                cornerRadius = dp(12).toFloat()
            }
        }
        controlsOverlay.addView(
            errorView,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER,
            ),
        )

        // Top Bar
        val statusBarHeight = getStatusBarHeight()
        val topBar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            background = GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM,
                intArrayOf(0xDD000000.toInt(), 0x77000000.toInt(), 0x00000000.toInt()),
            )
            setPadding(dp(10), statusBarHeight + dp(6), dp(10), dp(10))
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT_WATCH) {
                setOnApplyWindowInsetsListener { view, insets ->
                    val topInset = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        insets.getInsets(android.view.WindowInsets.Type.statusBars() or android.view.WindowInsets.Type.displayCutout()).top
                    } else {
                        @Suppress("DEPRECATION")
                        insets.systemWindowInsetTop
                    }
                    val safeTop = if (topInset > 0) topInset else statusBarHeight
                    view.setPadding(dp(10), safeTop + dp(6), dp(10), dp(10))
                    insets
                }
            }
        }

        val backButton = TextView(this).apply {
            text = "✕"
            textSize = 16f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            setPadding(dp(8), dp(4), dp(8), dp(4))
            background = GradientDrawable().apply {
                setColor(0x33FFFFFF.toInt())
                cornerRadius = dp(14).toFloat()
            }
            setOnClickListener { finish() }
        }

        val titleContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(8), 0, dp(8), 0)
        }

        titleView = TextView(this).apply {
            textSize = 12.5f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.WHITE)
            maxLines = 2
            setLineSpacing(dp(1).toFloat(), 1.05f)
            ellipsize = android.text.TextUtils.TruncateAt.END
            setShadowLayer(3f, 0f, 1f, Color.BLACK)
        }

        subtitleEpgView = TextView(this).apply {
            textSize = 10.5f
            setTextColor(0xFFCCCCCC.toInt())
            maxLines = 1
            ellipsize = android.text.TextUtils.TruncateAt.END
            visibility = View.GONE
        }

        titleContainer.addView(titleView)
        titleContainer.addView(subtitleEpgView)

        val pipButton = actionPillButton("⧉ PiP") { enterPipMode() }
        val epgButton = actionPillButton("☰ List") { openEpgDrawer() }
        val moreButton = actionPillButton("⋮ Menu") { showMoreMenu() }

        topBar.addView(backButton)
        topBar.addView(titleContainer, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        topBar.addView(pipButton, pillLayoutParams())
        topBar.addView(epgButton, pillLayoutParams())
        topBar.addView(moreButton, pillLayoutParams())

        controlsOverlay.addView(
            topBar,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.TOP,
            ),
        )

        // Bottom Controls Container (2 tiers: Timeline + Controls)
        val bottomContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setBackgroundColor(0xB0000000.toInt())
            setPadding(dp(8), dp(4), dp(8), dp(8))
        }

        // Timeline Row
        val timelineRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(4), 0, dp(4), dp(2))
        }

        currentTimeText = TextView(this).apply {
            text = if (isLiveStream) "● LIVE" else "00:00"
            textSize = 11f
            setTextColor(if (isLiveStream) 0xFFFF5252.toInt() else 0xFFE0E0E0.toInt())
            gravity = Gravity.CENTER
            setPadding(dp(4), 0, dp(4), 0)
        }

        val sb = SeekBar(this).apply {
            max = 1000
            progress = 0
            visibility = if (isLiveStream) View.GONE else View.VISIBLE
            setPadding(dp(8), 0, dp(8), 0)
            setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                override fun onProgressChanged(sBar: SeekBar?, progress: Int, fromUser: Boolean) {
                    if (fromUser && !isLiveStream) {
                        currentTimeText?.text = formatTime(progress.toLong())
                    }
                }

                override fun onStartTrackingTouch(sBar: SeekBar?) {
                    if (isLiveStream) return
                    isUserTrackingSeek = true
                    mainHandler.removeCallbacks(hideControlsRunnable)
                }

                override fun onStopTrackingTouch(sBar: SeekBar?) {
                    if (isLiveStream) return
                    isUserTrackingSeek = false
                    val targetMs = sBar?.progress?.toLong() ?: 0L
                    player?.seekTo(targetMs)
                    mainHandler.postDelayed(hideControlsRunnable, CONTROLS_AUTO_HIDE_MS)
                }
            })
        }
        seekBar = sb

        durationText = TextView(this).apply {
            text = "00:00"
            textSize = 11f
            visibility = if (isLiveStream) View.GONE else View.VISIBLE
            setTextColor(0xFFAAAAAA.toInt())
            gravity = Gravity.CENTER
            setPadding(dp(4), 0, dp(4), 0)
        }

        timelineRow.addView(currentTimeText)
        timelineRow.addView(sb, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        timelineRow.addView(durationText)

        // Transport & Action Controls Row
        val controlsRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(2), dp(2), dp(2), dp(2))
        }

        val isLandscape = resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE
        aspectRatioButton = actionPillButton(if (isLandscape) "Zoom" else "16:9") { showAspectRatioDialog() }
        speedButton = actionPillButton("1.0x") { showSpeedDialog() }

        val prevChannelBtn = transportButton("⏮") { previousChannel() }
        val rewBtn = transportButton("⏪") { seekRelative(-SEEK_STEP_MS) }
        rewindButton = rewBtn
        playPauseButton = transportButton("▶", isPlayPause = true) { togglePlayPause() }
        val fwdBtn = transportButton("⏩") { seekRelative(SEEK_STEP_MS) }
        forwardButton = fwdBtn
        val nextChannelBtn = transportButton("⏭") { nextChannel() }

        rewBtn.visibility = if (isLiveStream) View.GONE else View.VISIBLE
        fwdBtn.visibility = if (isLiveStream) View.GONE else View.VISIBLE

        qualityButton = actionPillButton("Auto") { showQualityDialog() }
        val audioButton = actionPillButton("Audio") { showAudioTracksDialog() }

        // Left section
        val leftActions = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.START or Gravity.CENTER_VERTICAL
        }
        leftActions.addView(aspectRatioButton, pillLayoutParams())
        leftActions.addView(speedButton, pillLayoutParams())

        // Center transport
        val centerTransport = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
        }
        centerTransport.addView(prevChannelBtn, transportLayoutParams())
        centerTransport.addView(rewBtn, transportLayoutParams())
        centerTransport.addView(playPauseButton, transportLayoutParams(isPlayPause = true))
        centerTransport.addView(fwdBtn, transportLayoutParams())
        centerTransport.addView(nextChannelBtn, transportLayoutParams())

        // Right section
        val rightActions = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.END or Gravity.CENTER_VERTICAL
        }
        rightActions.addView(qualityButton, pillLayoutParams())
        rightActions.addView(audioButton, pillLayoutParams())

        controlsRow.addView(leftActions, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        controlsRow.addView(centerTransport, LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        controlsRow.addView(rightActions, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))

        bottomContainer.addView(timelineRow, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        bottomContainer.addView(controlsRow, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))

        controlsOverlay.addView(
            bottomContainer,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM,
            ),
        )

        root.addView(
            controlsOverlay,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            ),
        )

        setContentView(root)
        applyImmersiveMode()
        setControlsVisible(true)
    }

    private fun getStatusBarHeight(): Int {
        var result = dp(24)
        val resourceId = resources.getIdentifier("status_bar_height", "dimen", "android")
        if (resourceId > 0) {
            result = resources.getDimensionPixelSize(resourceId)
        }
        return result
    }

    private fun pillLayoutParams(): LinearLayout.LayoutParams {
        return LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
        ).apply {
            setMargins(dp(2), 0, dp(2), 0)
        }
    }

    private fun transportLayoutParams(isPlayPause: Boolean = false): LinearLayout.LayoutParams {
        val size = if (isPlayPause) dp(38) else dp(32)
        return LinearLayout.LayoutParams(size, size).apply {
            setMargins(dp(2), 0, dp(2), 0)
        }
    }

    private fun actionPillButton(
        label: String,
        onClick: () -> Unit,
    ): TextView = TextView(this).apply {
        text = label
        textSize = 11f
        setTextColor(0xFFEEEEEE.toInt())
        gravity = Gravity.CENTER
        setPadding(dp(8), dp(4), dp(8), dp(4))
        background = GradientDrawable().apply {
            setColor(0x55333333.toInt())
            cornerRadius = dp(10).toFloat()
        }
        setOnClickListener { onClick() }
    }

    private fun transportButton(
        icon: String,
        isPlayPause: Boolean = false,
        onClick: () -> Unit,
    ): TextView = TextView(this).apply {
        text = icon
        textSize = if (isPlayPause) 18f else 14f
        setTextColor(Color.WHITE)
        gravity = Gravity.CENTER
        background = GradientDrawable().apply {
            if (isPlayPause) {
                setColor(0xEE3F51B5.toInt())
                cornerRadius = dp(19).toFloat()
            } else {
                setColor(0x44FFFFFF.toInt())
                cornerRadius = dp(16).toFloat()
            }
        }
        setOnClickListener { onClick() }
    }

    // ---- Picture-in-Picture (PiP) -------------------------------------------

    fun enterPipMode() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val rational = if (videoWidth > 0 && videoHeight > 0) {
                    Rational(videoWidth, videoHeight)
                } else {
                    Rational(16, 9)
                }
                val params = PictureInPictureParams.Builder()
                    .setAspectRatio(rational)
                    .build()
                enterPictureInPictureMode(params)
            } catch (e: Exception) {
                Toast.makeText(this, "PiP not supported: ${e.message}", Toast.LENGTH_SHORT).show()
            }
        } else {
            Toast.makeText(this, "PiP requires Android 8.0+", Toast.LENGTH_SHORT).show()
        }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration,
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        if (isInPictureInPictureMode) {
            controlsOverlay.visibility = View.GONE
            hudOverlay.visibility = View.GONE
            if (::epgDrawer.isInitialized) epgDrawer.visibility = View.GONE
        } else {
            controlsOverlay.visibility = View.VISIBLE
            hudOverlay.visibility = View.VISIBLE
            setControlsVisible(true)
        }
        emit("onPipChanged", mapOf("inPip" to isInPictureInPictureMode))
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (player?.playWhenReady == true && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            enterPipMode()
        }
    }

    // ---- EPG Drawer & Quick Channel / Category Switcher --------------------

    private fun setupEpgDrawer() {
        epgDrawer = FrameLayout(this).apply {
            background = GradientDrawable(
                GradientDrawable.Orientation.LEFT_RIGHT,
                intArrayOf(0xF8111622.toInt(), 0xF80B0D14.toInt()),
            )
            visibility = View.GONE
            isClickable = true
            isFocusable = true
            elevation = dp(16).toFloat()
        }

        val drawerContent = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16), dp(16), dp(16), dp(16))
        }

        // Header (Title, Badge, Close Button)
        val header = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        val headerTitle = TextView(this).apply {
            text = "Channels & Categories"
            textSize = 17f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.WHITE)
        }
        channelListTitleView = headerTitle

        val countBadge = TextView(this).apply {
            text = "0 channels"
            textSize = 11f
            setTextColor(0xFF81C784.toInt())
            setPadding(dp(8), dp(2), dp(8), dp(2))
            background = GradientDrawable().apply {
                setColor(0x224CAF50.toInt())
                cornerRadius = dp(10).toFloat()
            }
        }
        channelCountBadge = countBadge

        val closeDrawerBtn = TextView(this).apply {
            text = "✕"
            textSize = 18f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            setPadding(dp(10), dp(6), dp(10), dp(6))
            background = GradientDrawable().apply {
                setColor(0x22FFFFFF.toInt())
                cornerRadius = dp(14).toFloat()
            }
            setOnClickListener { closeEpgDrawer() }
        }

        val titleCol = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            addView(headerTitle)
            addView(countBadge, LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                topMargin = dp(2)
            })
        }

        header.addView(titleCol, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        header.addView(closeDrawerBtn)
        drawerContent.addView(header)

        // Search Bar Box
        val searchBox = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(10), dp(4), dp(10), dp(4))
            background = GradientDrawable().apply {
                setColor(0x22FFFFFF.toInt())
                cornerRadius = dp(8).toFloat()
                setStroke(dp(1), 0x33FFFFFF.toInt())
            }
        }
        val searchIcon = TextView(this).apply {
            text = "🔍"
            textSize = 13f
            setPadding(0, 0, dp(6), 0)
        }
        val searchInput = EditText(this).apply {
            hint = "Search channels..."
            setHintTextColor(0xFF888888.toInt())
            setTextColor(Color.WHITE)
            textSize = 13f
            background = null
            maxLines = 1
            isSingleLine = true
            addTextChangedListener(object : TextWatcher {
                override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
                override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
                override fun afterTextChanged(s: Editable?) {
                    searchQuery = s?.toString() ?: ""
                    filterChannels()
                }
            })
        }
        searchEditText = searchInput

        val clearSearchBtn = TextView(this).apply {
            text = "✕"
            textSize = 12f
            setTextColor(0xFF888888.toInt())
            setPadding(dp(6), dp(4), dp(6), dp(4))
            setOnClickListener { searchInput.setText("") }
        }

        searchBox.addView(searchIcon)
        searchBox.addView(searchInput, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        searchBox.addView(clearSearchBtn)

        drawerContent.addView(
            searchBox,
            LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                topMargin = dp(10)
                bottomMargin = dp(8)
            },
        )

        // Categories Horizontal Chips
        val categoryScrollView = HorizontalScrollView(this).apply {
            isHorizontalScrollBarEnabled = false
        }
        val chipsContainer = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(0, dp(2), 0, dp(6))
        }
        categoryChipsContainer = chipsContainer
        categoryScrollView.addView(chipsContainer)

        drawerContent.addView(
            categoryScrollView,
            LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT),
        )

        // Channel List View
        channelListView = ListView(this).apply {
            divider = ColorDrawable(0x18FFFFFF.toInt())
            dividerHeight = 1
        }

        channelListView.adapter = object : BaseAdapter() {
            override fun getCount(): Int = displayedChannels.size
            override fun getItem(position: Int): Any = displayedChannels[position]
            override fun getItemId(position: Int): Long = position.toLong()

            override fun getView(position: Int, convertView: View?, parent: ViewGroup?): View {
                val item = displayedChannels[position]
                val originalIndex = channelList.indexOfFirst { it.id == item.id }
                val isCurrent = (originalIndex == currentChannelIndex) || (item.name == channelTitle)

                val row = convertView as? LinearLayout ?: LinearLayout(this@NativePlayerActivity).apply {
                    orientation = LinearLayout.VERTICAL
                    setPadding(dp(12), dp(10), dp(12), dp(10))
                }

                val topRow = LinearLayout(this@NativePlayerActivity).apply {
                    orientation = LinearLayout.HORIZONTAL
                    gravity = Gravity.CENTER_VERTICAL
                }

                val rowNum = TextView(this@NativePlayerActivity).apply {
                    text = "${if (originalIndex >= 0) originalIndex + 1 else position + 1}."
                    textSize = 12f
                    setTextColor(if (isCurrent) 0xFF4CAF50.toInt() else 0xFF777777.toInt())
                    setPadding(0, 0, dp(6), 0)
                }

                val rowTitle = TextView(this@NativePlayerActivity).apply {
                    text = item.name
                    textSize = 14f
                    typeface = if (isCurrent) Typeface.DEFAULT_BOLD else Typeface.DEFAULT
                    setTextColor(if (isCurrent) 0xFF4CAF50.toInt() else Color.WHITE)
                    maxLines = 1
                    ellipsize = android.text.TextUtils.TruncateAt.END
                }

                topRow.addView(rowNum)
                topRow.addView(rowTitle, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))

                if (isCurrent) {
                    val playingBadge = TextView(this@NativePlayerActivity).apply {
                        text = "▶ PLAYING"
                        textSize = 9f
                        typeface = Typeface.DEFAULT_BOLD
                        setTextColor(0xFF4CAF50.toInt())
                        setPadding(dp(6), dp(2), dp(6), dp(2))
                        background = GradientDrawable().apply {
                            setColor(0x334CAF50.toInt())
                            cornerRadius = dp(4).toFloat()
                        }
                    }
                    topRow.addView(playingBadge)
                }

                val subRow = LinearLayout(this@NativePlayerActivity).apply {
                    orientation = LinearLayout.HORIZONTAL
                    gravity = Gravity.CENTER_VERTICAL
                }

                if (!item.category.isNullOrBlank()) {
                    val catBadge = TextView(this@NativePlayerActivity).apply {
                        text = item.category
                        textSize = 10f
                        setTextColor(0xFF3B82F6.toInt())
                        setPadding(dp(4), dp(1), dp(4), dp(1))
                        background = GradientDrawable().apply {
                            setColor(0x223B82F6.toInt())
                            cornerRadius = dp(3).toFloat()
                        }
                    }
                    subRow.addView(catBadge)
                }

                val rowEpg = TextView(this@NativePlayerActivity).apply {
                    text = if (!item.epgTitle.isNullOrBlank()) "  ${item.epgTitle}" else if (item.category.isNullOrBlank()) "Live Channel" else ""
                    textSize = 11f
                    setTextColor(if (isCurrent) 0xFF81C784.toInt() else 0xFF888888.toInt())
                    maxLines = 1
                    ellipsize = android.text.TextUtils.TruncateAt.END
                }
                subRow.addView(rowEpg, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))

                row.removeAllViews()
                row.addView(topRow)
                row.addView(subRow)

                row.background = GradientDrawable().apply {
                    setColor(if (isCurrent) 0x2E4CAF50.toInt() else Color.TRANSPARENT)
                    cornerRadius = dp(6).toFloat()
                }

                row.setOnClickListener {
                    val targetIdx = if (originalIndex >= 0) originalIndex else position
                    switchChannelByIndex(targetIdx)
                    closeEpgDrawer()
                }

                return row
            }
        }

        // Empty State View
        val emptyText = TextView(this).apply {
            text = "No channels loaded.\nFetching channels..."
            textSize = 13f
            setTextColor(0xFF999999.toInt())
            gravity = Gravity.CENTER
            setPadding(dp(20), dp(40), dp(20), dp(40))
            visibility = View.GONE
        }
        emptyStateView = emptyText

        drawerContent.addView(
            channelListView,
            LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f).apply {
                topMargin = dp(6)
            },
        )
        drawerContent.addView(
            emptyText,
            LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                topMargin = dp(20)
            },
        )

        epgDrawer.addView(
            drawerContent,
            FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT),
        )

        val drawerWidth = (resources.displayMetrics.widthPixels * 0.48f).toInt().coerceIn(dp(260), dp(460))
        root.addView(
            epgDrawer,
            FrameLayout.LayoutParams(drawerWidth, ViewGroup.LayoutParams.MATCH_PARENT, Gravity.END),
        )
    }

    private fun rebuildCategoriesAndFilter() {
        val categoriesSet = linkedSetOf("All Channels")
        channelList.forEach { item ->
            val cat = item.category?.trim()
            if (!cat.isNullOrEmpty()) {
                categoriesSet.add(cat)
            }
        }
        allCategories = categoriesSet.toList()
        if (selectedCategory !in allCategories) {
            selectedCategory = "All Channels"
        }
        filterChannels()
        refreshCategoryChips()
    }

    private fun filterChannels() {
        val q = searchQuery.trim().lowercase()
        displayedChannels.clear()
        channelList.forEach { item ->
            val matchesCategory = (selectedCategory == "All Channels") ||
                    (item.category?.equals(selectedCategory, ignoreCase = true) == true)
            val matchesSearch = q.isEmpty() ||
                    item.name.lowercase().contains(q) ||
                    (item.epgTitle?.lowercase()?.contains(q) == true)
            if (matchesCategory && matchesSearch) {
                displayedChannels.add(item)
            }
        }
        channelListTitleView?.text = "Channels (${channelList.size})"
        channelCountBadge?.text = "${displayedChannels.size} channels"
        if (displayedChannels.isEmpty()) {
            emptyStateView?.visibility = View.VISIBLE
            channelListView.visibility = View.GONE
            if (channelList.isEmpty()) {
                emptyStateView?.text = "No channels loaded.\nFetching playlist channels..."
            } else {
                emptyStateView?.text = "No channels matching \"$searchQuery\" in $selectedCategory"
            }
        } else {
            emptyStateView?.visibility = View.GONE
            channelListView.visibility = View.VISIBLE
        }
        (channelListView.adapter as? BaseAdapter)?.notifyDataSetChanged()
    }

    private fun refreshCategoryChips() {
        val container = categoryChipsContainer ?: return
        container.removeAllViews()
        allCategories.forEach { category ->
            val isSelected = category == selectedCategory
            val chip = TextView(this).apply {
                text = category
                textSize = 12f
                typeface = if (isSelected) Typeface.DEFAULT_BOLD else Typeface.DEFAULT
                setTextColor(if (isSelected) Color.WHITE else 0xFFB0B0B0.toInt())
                setPadding(dp(12), dp(6), dp(12), dp(6))
                background = GradientDrawable().apply {
                    cornerRadius = dp(14).toFloat()
                    if (isSelected) {
                        setColor(0xFF3B82F6.toInt())
                    } else {
                        setColor(0x22FFFFFF.toInt())
                        setStroke(dp(1), 0x33FFFFFF.toInt())
                    }
                }
                setOnClickListener {
                    selectedCategory = category
                    filterChannels()
                    refreshCategoryChips()
                    channelListView.setSelection(0)
                }
            }
            val lp = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply {
                marginEnd = dp(6)
            }
            container.addView(chip, lp)
        }
    }

    private fun openEpgDrawer() {
        isEpgDrawerOpen = true
        epgDrawer.visibility = View.VISIBLE
        epgDrawer.bringToFront()
        setControlsVisible(false)
        rebuildCategoriesAndFilter()
        if (channelList.size <= 1) {
            emit("onFetchChannelsRequested", emptyMap<String, Any>())
        }
        if (currentChannelIndex in channelList.indices) {
            val currentInDisplayed = displayedChannels.indexOfFirst {
                it.id == channelList[currentChannelIndex].id
            }
            if (currentInDisplayed >= 0) {
                channelListView.setSelection(currentInDisplayed)
            }
        }
    }

    private fun closeEpgDrawer() {
        isEpgDrawerOpen = false
        epgDrawer.visibility = View.GONE
    }

    fun switchChannelByIndex(index: Int) {
        if (index !in channelList.indices) return
        currentChannelIndex = index
        val item = channelList[index]
        channelTitle = item.name
        titleView?.text = item.name
        if (!item.epgTitle.isNullOrBlank()) {
            subtitleEpgView?.text = item.epgTitle
            subtitleEpgView?.visibility = View.VISIBLE
        } else {
            subtitleEpgView?.visibility = View.GONE
        }
        (channelListView.adapter as? BaseAdapter)?.notifyDataSetChanged()
        emit("onChannelChanged", mapOf(
            "channelId" to item.id,
            "name" to item.name,
            "index" to index,
            "url" to item.url,
        ))
        if (item.url.isNotEmpty()) {
            loadStream(item.url, item.headers, item.name, item.epgTitle)
        } else {
            emit("onResolveChannelRequested", mapOf(
                "channelId" to item.id,
                "index" to index,
            ))
        }
    }

    fun nextChannel() {
        if (channelList.isNotEmpty()) {
            val next = (currentChannelIndex + 1) % channelList.size
            switchChannelByIndex(next)
        } else {
            emit("onNextChannelRequested", emptyMap<String, Any>())
        }
    }

    fun previousChannel() {
        if (channelList.isNotEmpty()) {
            val prev = if (currentChannelIndex - 1 < 0) channelList.size - 1 else currentChannelIndex - 1
            switchChannelByIndex(prev)
        } else {
            emit("onPreviousChannelRequested", emptyMap<String, Any>())
        }
    }

    // ---- Menus & Dialogs ----------------------------------------------------

    private fun showMoreMenu() {
        val options = arrayOf(
            "\uD83C\uDF99 Audio Tracks",
            "\uD83D\uDCAC Subtitles",
            "\u23E9 Playback Speed (${currentSpeed}x)",
            "\uD83D\uDCFA Aspect Ratio",
            "⚙ Video Quality",
        )

        AlertDialog.Builder(this)
            .setTitle("Player Settings")
            .setItems(options) { dialog, which ->
                dialog.dismiss()
                when (which) {
                    0 -> showAudioTracksDialog()
                    1 -> showSubtitlesDialog()
                    2 -> showSpeedDialog()
                    3 -> showAspectRatioDialog()
                    4 -> showQualityDialog()
                }
            }
            .setNegativeButton("Close", null)
            .show()
    }

    private fun showAudioTracksDialog() {
        val exo = player ?: return
        val audioGroups = exo.currentTracks.groups.filter { it.type == C.TRACK_TYPE_AUDIO && it.length > 0 }
        if (audioGroups.isEmpty()) {
            Toast.makeText(this, "No alternate audio tracks available.", Toast.LENGTH_SHORT).show()
            return
        }

        val trackLabels = mutableListOf<String>()
        val trackRefs = mutableListOf<Pair<Tracks.Group, Int>>()

        for (group in audioGroups) {
            for (i in 0 until group.length) {
                val format = group.getTrackFormat(i)
                val lang = format.language?.uppercase() ?: "Undetermined"
                val label = format.label ?: "$lang (Audio ${trackLabels.size + 1})"
                trackLabels.add(label)
                trackRefs.add(group to i)
            }
        }

        AlertDialog.Builder(this)
            .setTitle("Audio Tracks")
            .setItems(trackLabels.toTypedArray()) { dialog, which ->
                val (group, trackIdx) = trackRefs[which]
                val override = TrackSelectionOverride(group.mediaTrackGroup, listOf(trackIdx))
                exo.trackSelectionParameters = exo.trackSelectionParameters.buildUpon()
                    .clearOverridesOfType(C.TRACK_TYPE_AUDIO)
                    .setOverrideForType(override)
                    .build()
                Toast.makeText(this, "Audio: ${trackLabels[which]}", Toast.LENGTH_SHORT).show()
                dialog.dismiss()
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun showSubtitlesDialog() {
        val exo = player ?: return
        val textGroups = exo.currentTracks.groups.filter { it.type == C.TRACK_TYPE_TEXT && it.length > 0 }

        val labels = mutableListOf("Off / Disabled")
        val refs = mutableListOf<Pair<Tracks.Group, Int>?>()
        refs.add(null)

        for (group in textGroups) {
            for (i in 0 until group.length) {
                val format = group.getTrackFormat(i)
                val lang = format.language?.uppercase() ?: "Subtitle"
                val label = format.label ?: "$lang (${labels.size})"
                labels.add(label)
                refs.add(group to i)
            }
        }

        AlertDialog.Builder(this)
            .setTitle("Subtitles")
            .setItems(labels.toTypedArray()) { dialog, which ->
                val ref = refs[which]
                if (ref == null) {
                    exo.trackSelectionParameters = exo.trackSelectionParameters.buildUpon()
                        .clearOverridesOfType(C.TRACK_TYPE_TEXT)
                        .setTrackTypeDisabled(C.TRACK_TYPE_TEXT, true)
                        .build()
                    Toast.makeText(this, "Subtitles disabled", Toast.LENGTH_SHORT).show()
                } else {
                    val (group, trackIdx) = ref
                    val override = TrackSelectionOverride(group.mediaTrackGroup, listOf(trackIdx))
                    exo.trackSelectionParameters = exo.trackSelectionParameters.buildUpon()
                        .setTrackTypeDisabled(C.TRACK_TYPE_TEXT, false)
                        .clearOverridesOfType(C.TRACK_TYPE_TEXT)
                        .setOverrideForType(override)
                        .build()
                    Toast.makeText(this, "Subtitle: ${labels[which]}", Toast.LENGTH_SHORT).show()
                }
                dialog.dismiss()
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun showSpeedDialog() {
        val speeds = listOf(0.5f, 0.75f, 1.0f, 1.25f, 1.5f, 2.0f)
        val labels = speeds.map { if (it == 1.0f) "1.0x (Normal)" else "${it}x" }
        val currentIndex = speeds.indexOf(currentSpeed).coerceAtLeast(0)

        AlertDialog.Builder(this)
            .setTitle("Playback Speed")
            .setSingleChoiceItems(labels.toTypedArray(), currentIndex) { dialog, which ->
                setSpeed(speeds[which])
                dialog.dismiss()
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun showAspectRatioDialog() {
        val modes = AspectRatioMode.values()
        val labels = modes.map {
            when (it) {
                AspectRatioMode.FIT -> "Fit (Original Aspect)"
                AspectRatioMode.ZOOM -> "Zoom (Fill Screen)"
                AspectRatioMode.STRETCH -> "Stretch to Screen"
                AspectRatioMode.SIXTEEN_NINE -> "16:9 (Default)"
                AspectRatioMode.FOUR_THREE -> "4:3 Classic"
            }
        }
        val currentIndex = modes.indexOf(currentAspectRatio).coerceAtLeast(0)

        AlertDialog.Builder(this)
            .setTitle("Aspect Ratio")
            .setSingleChoiceItems(labels.toTypedArray(), currentIndex) { dialog, which ->
                userSelectedAspectRatio = true
                currentAspectRatio = modes[which]
                applyAspectRatioTransform()
                aspectRatioButton?.text = when (currentAspectRatio) {
                    AspectRatioMode.FIT -> "Fit"
                    AspectRatioMode.ZOOM -> "Zoom"
                    AspectRatioMode.STRETCH -> "Stretch"
                    AspectRatioMode.SIXTEEN_NINE -> "16:9"
                    AspectRatioMode.FOUR_THREE -> "4:3"
                }
                dialog.dismiss()
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun applyAspectRatioTransform() {
        val surface = videoSurface ?: return
        val viewWidth = surface.width.toFloat()
        val viewHeight = surface.height.toFloat()
        if (viewWidth <= 0 || viewHeight <= 0 || videoWidth <= 0 || videoHeight <= 0) return

        val matrix = Matrix()
        val viewAspect = viewWidth / viewHeight
        val videoAspect = videoWidth.toFloat() / videoHeight.toFloat()

        when (currentAspectRatio) {
            AspectRatioMode.FIT -> {
                val scaleX = if (viewAspect > videoAspect) videoAspect / viewAspect else 1.0f
                val scaleY = if (viewAspect > videoAspect) 1.0f else viewAspect / videoAspect
                matrix.setScale(scaleX, scaleY, viewWidth / 2f, viewHeight / 2f)
                surface.setTransform(matrix)
            }
            AspectRatioMode.ZOOM -> {
                val scale = if (viewAspect > videoAspect) {
                    viewWidth / (viewHeight * videoAspect)
                } else {
                    viewHeight / (viewWidth / videoAspect)
                }
                matrix.setScale(scale, scale, viewWidth / 2f, viewHeight / 2f)
                surface.setTransform(matrix)
            }
            AspectRatioMode.STRETCH -> {
                val scaleX = 1.0f
                val scaleY = 1.0f
                matrix.setScale(scaleX, scaleY, viewWidth / 2f, viewHeight / 2f)
                surface.setTransform(matrix)
            }
            AspectRatioMode.SIXTEEN_NINE -> {
                val targetAspect = 16f / 9f
                val scaleX = if (viewAspect > targetAspect) targetAspect / viewAspect else 1.0f
                val scaleY = if (viewAspect > targetAspect) 1.0f else viewAspect / targetAspect
                matrix.setScale(scaleX, scaleY, viewWidth / 2f, viewHeight / 2f)
                surface.setTransform(matrix)
            }
            AspectRatioMode.FOUR_THREE -> {
                val targetAspect = 4f / 3f
                val scaleX = if (viewAspect > targetAspect) targetAspect / viewAspect else 1.0f
                val scaleY = if (viewAspect > targetAspect) 1.0f else viewAspect / targetAspect
                matrix.setScale(scaleX, scaleY, viewWidth / 2f, viewHeight / 2f)
                surface.setTransform(matrix)
            }
        }
    }

    private fun showQualityDialog() {
        val exo = player ?: return
        val videoGroups = exo.currentTracks.groups
            .filter { it.type == C.TRACK_TYPE_VIDEO && it.length > 0 }
        if (videoGroups.isEmpty()) {
            Toast.makeText(this, "No video quality information available.", Toast.LENGTH_SHORT).show()
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
            .setTitle("Video Quality")
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
                Toast.makeText(this, "${resolution}p not available; keeping Auto.", Toast.LENGTH_SHORT).show()
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

    // ---- Loading & Playback -------------------------------------------------

    private fun parseIntent() {
        streamUrl = intent.getStringExtra(EXTRA_URL) ?: ""
        headers = (intent.getSerializableExtra(EXTRA_HEADERS) as? Map<*, *>)
            ?.entries
            ?.associate { it.key.toString() to it.value.toString() }
            ?: emptyMap()
        channelTitle = intent.getStringExtra(EXTRA_TITLE)
        val channelIndex = intent.getIntExtra(EXTRA_CHANNEL_INDEX, -1)
        if (channelIndex >= 0) {
            currentChannelIndex = channelIndex
        }
        isLiveIntent = intent.getBooleanExtra(EXTRA_IS_LIVE, false)
    }

    private fun buildPlayer(): ExoPlayer {
        val renderersFactory = DefaultRenderersFactory(this)
            .setEnableDecoderFallback(true)
            .setExtensionRendererMode(DefaultRenderersFactory.EXTENSION_RENDERER_MODE_PREFER)
            .setMediaCodecSelector(MediaCodecSelector.DEFAULT)

        val trackSelector = DefaultTrackSelector(this).apply {
            parameters = buildUponParameters()
                .setAllowMultipleAdaptiveSelections(true)
                .setExceedRendererCapabilitiesIfNecessary(false)
                .build()
        }

        val audioAttributes = androidx.media3.common.AudioAttributes.Builder()
            .setUsage(C.USAGE_MEDIA)
            .setContentType(C.AUDIO_CONTENT_TYPE_MOVIE)
            .build()

        return ExoPlayer.Builder(this, renderersFactory)
            .setTrackSelector(trackSelector)
            .setAudioAttributes(audioAttributes, /* handleAudioFocus = */ true)
            .setHandleAudioBecomingNoisy(true)
            .setWakeMode(C.WAKE_MODE_NETWORK)
            .build()
    }

    fun loadStream(url: String, headers: Map<String, String>, title: String?, epgTitle: String? = null) {
        if (url.isEmpty()) {
            showError("No stream URL was provided.")
            return
        }
        val uri = Uri.parse(url)
        if (!uri.isAbsolute) {
            showError("Invalid stream URL: $url")
            return
        }
        titleView?.text = title?.takeIf { it.isNotBlank() } ?: "Now Playing"
        if (!epgTitle.isNullOrBlank()) {
            subtitleEpgView?.text = epgTitle
            subtitleEpgView?.visibility = View.VISIBLE
        } else {
            subtitleEpgView?.visibility = View.GONE
        }

        try {
            val exo = player ?: return
            // Stop and clear previous stream immediately to release socket / connection slots on server
            exo.stop()
            exo.clearMediaItems()

            val httpDataSourceFactory = buildHttpDataSourceFactory(headers)
            val mediaItem = MediaItem.Builder().setUri(uri).build()

            // Custom extractors factory for IPTV MPEG-TS with robust audio stream detection
            val extractorsFactory = DefaultExtractorsFactory().apply {
                setTsExtractorFlags(
                    DefaultTsPayloadReaderFactory.FLAG_ALLOW_NON_IDR_KEYFRAMES or
                    DefaultTsPayloadReaderFactory.FLAG_DETECT_ACCESS_UNITS or
                    DefaultTsPayloadReaderFactory.FLAG_ENABLE_HDMV_DTS_AUDIO_STREAMS or
                    DefaultTsPayloadReaderFactory.FLAG_IGNORE_SPLICE_INFO_STREAM,
                )
                setConstantBitrateSeekingEnabled(true)
            }

            val urlString = uri.toString().lowercase()
            val isHls = urlString.contains(".m3u8") ||
                urlString.contains("extension=m3u8") ||
                urlString.contains("format=m3u8") ||
                urlString.contains("output=m3u8") ||
                urlString.contains("type=m3u8") ||
                urlString.contains("/hls/") ||
                Util.inferContentType(uri, "") == C.CONTENT_TYPE_HLS

            val mediaSource: MediaSource = when {
                isHls -> HlsMediaSource.Factory(httpDataSourceFactory).createMediaSource(mediaItem)
                Util.inferContentType(uri, "") == C.CONTENT_TYPE_DASH -> DashMediaSource.Factory(httpDataSourceFactory).createMediaSource(mediaItem)
                Util.inferContentType(uri, "") == C.CONTENT_TYPE_RTSP -> RtspMediaSource.Factory().createMediaSource(mediaItem)
                else -> ProgressiveMediaSource.Factory(httpDataSourceFactory, extractorsFactory).createMediaSource(mediaItem)
            }
            loadingSpinner?.visibility = View.VISIBLE
            errorView?.visibility = View.GONE
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

        try {
            val cookieManager = (java.net.CookieHandler.getDefault() as? java.net.CookieManager)
                ?: java.net.CookieManager(null, java.net.CookiePolicy.ACCEPT_ALL).also {
                    java.net.CookieHandler.setDefault(it)
                }
            val cookieVal = headers["Cookie"] ?: headers["cookie"]
            if (!cookieVal.isNullOrBlank() && streamUrl.isNotBlank()) {
                val uriObj = java.net.URI.create(streamUrl)
                for (part in cookieVal.split(";")) {
                    val trimmed = part.trim()
                    if (trimmed.isNotBlank()) {
                        try {
                            val parsedCookies = java.net.HttpCookie.parse(trimmed)
                            for (c in parsedCookies) {
                                cookieManager.cookieStore.add(uriObj, c)
                            }
                        } catch (_: Exception) {}
                    }
                }
            }
        } catch (_: Exception) {}

        return DefaultHttpDataSource.Factory()
            .setUserAgent(userAgent)
            .setDefaultRequestProperties(requestProperties)
            .setAllowCrossProtocolRedirects(true)
            .setConnectTimeoutMs(CONNECT_TIMEOUT_MS)
            .setReadTimeoutMs(READ_TIMEOUT_MS)
            .setKeepPostFor302Redirects(true)
    }

    // ---- Controls Toggle & Transport ----------------------------------------

    private fun toggleControls() {
        setControlsVisible(!controlsVisible)
    }

    private fun setControlsVisible(visible: Boolean) {
        controlsVisible = visible
        val childCount = controlsOverlay.childCount
        for (i in 0 until childCount) {
            val child = controlsOverlay.getChildAt(i)
            if (child === loadingSpinner || child === errorView) continue
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
        playPauseButton?.text = if (player?.playWhenReady == true) "⏸" else "▶"
    }

    private fun seekRelative(deltaMs: Long) {
        if (isLiveStream) return
        val exo = player ?: return
        val duration = if (exo.duration == C.TIME_UNSET) Long.MAX_VALUE else exo.duration
        val target = (exo.currentPosition + deltaMs).coerceIn(0L, duration)
        exo.seekTo(target)
    }

    private fun showError(message: String) {
        errorView?.text = message
        errorView?.visibility = View.VISIBLE
        loadingSpinner?.visibility = View.GONE
    }

    // ---- Flutter Bridge Events ----------------------------------------------

    private fun emitPosition() {
        val exo = player ?: return
        if (exo.playbackState == Player.STATE_IDLE) return
        val pos = exo.currentPosition
        val dur = if (exo.duration == C.TIME_UNSET) 0L else exo.duration
        val buf = exo.bufferedPosition

        if (isLiveStream) {
            rewindButton?.visibility = View.GONE
            forwardButton?.visibility = View.GONE
            seekBar?.visibility = View.GONE
            durationText?.visibility = View.GONE
            currentTimeText?.text = "● LIVE"
            currentTimeText?.setTextColor(0xFFFF5252.toInt())
        } else {
            rewindButton?.visibility = View.VISIBLE
            forwardButton?.visibility = View.VISIBLE
            seekBar?.visibility = View.VISIBLE
            durationText?.visibility = View.VISIBLE
            currentTimeText?.setTextColor(0xFFE0E0E0.toInt())
            if (!isUserTrackingSeek && dur > 0) {
                seekBar?.max = dur.toInt()
                seekBar?.progress = pos.toInt()
                currentTimeText?.text = formatTime(pos)
                durationText?.text = formatTime(dur)
            }
        }

        emit(
            "onPosition",
            mapOf(
                "positionMs" to pos,
                "bufferedMs" to buf,
                "durationMs" to dur,
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

    // ---- Commands from Dart -------------------------------------------------

    fun playCommand() {
        player?.play()
        updatePlayPauseIcon()
    }

    fun pauseCommand() {
        player?.pause()
        updatePlayPauseIcon()
    }

    fun seekTo(positionMs: Long) {
        if (isLiveStream) return
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
        currentSpeed = speed.coerceIn(0.25f, 4f)
        player?.playbackParameters = PlaybackParameters(currentSpeed)
        speedButton?.text = "${currentSpeed}x"
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

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        if (isEpgDrawerOpen) {
            closeEpgDrawer()
            return
        }
        super.onBackPressed()
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
        audioManager.requestAudioFocus(request)
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
        audioManager.abandonAudioFocusRequest(request)
    }
}
