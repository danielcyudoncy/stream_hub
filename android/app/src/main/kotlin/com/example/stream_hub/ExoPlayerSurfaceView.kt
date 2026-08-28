package com.example.stream_hub

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.view.View
import android.widget.FrameLayout
import androidx.annotation.OptIn
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.Player
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.VideoSize
import androidx.media3.common.util.UnstableApi
import androidx.media3.common.util.Util
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.dash.DashMediaSource
import androidx.media3.exoplayer.hls.HlsMediaSource
import androidx.media3.exoplayer.mediacodec.MediaCodecSelector
import androidx.media3.exoplayer.rtsp.RtspMediaSource
import androidx.media3.exoplayer.source.MediaSource
import androidx.media3.exoplayer.source.ProgressiveMediaSource
import androidx.media3.extractor.DefaultExtractorsFactory
import androidx.media3.extractor.ts.DefaultTsPayloadReaderFactory
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView

/**
 * Android platform view that hosts an ExoPlayer (Media3) backend rendered
 * through a [PlayerView] backed by a hardware [android.view.SurfaceView].
 *
 * Render path: ExoPlayer's MediaCodec pipeline renders directly into the
 * hardware Surface composited by SurfaceFlinger in hybrid-composition mode.
 *
 * Control plane: a per-view [MethodChannel] (`stream_hub/exo_surface_<id>`)
 * carries commands from the Dart adapter; a per-view [EventChannel]
 * (`stream_hub/exo_surface_events_<id>`) streams playback events back.
 */
@OptIn(markerClass = [UnstableApi::class])
class ExoPlayerSurfaceView(
    context: Context,
    messenger: BinaryMessenger,
    viewId: Int,
    private val hardwareDecode: Boolean,
) : PlatformView, MethodChannel.MethodCallHandler {

    companion object {
        const val viewType = "com.example.stream_hub/exo_surface"

        private const val DEFAULT_USER_AGENT = "StreamHubPro/1.0 (Android)"
        private const val CONNECT_TIMEOUT_MS = 15_000
        private const val READ_TIMEOUT_MS = 15_000
        private const val POSITION_INTERVAL_MS = 250L

        // Controlled reconnect budget for transient network failures only
        // (mirrors NativePlayerActivity). Permanent errors surface immediately.
        private const val MAX_RECONNECT_ATTEMPTS = 3
        private const val RECONNECT_BASE_DELAY_MS = 2_000L
        private const val RECONNECT_MAX_DELAY_MS = 8_000L

        private const val MIN_BUFFER_MS = 45_000
        private const val MAX_BUFFER_MS = 60_000
        private const val BUFFER_FOR_PLAYBACK_MS = 2_500
        private const val BUFFER_FOR_PLAYBACK_AFTER_REBUFFER_MS = 5_000
        private const val BACK_BUFFER_DURATION_MS = 10_000

        // Grace period between STATE_READY and the first rendered video frame;
        // mirrors NativePlayerActivity. Only armed when a video track exists.
        private const val RENDER_WATCHDOG_MS = 10_000L
    }

    private val player: ExoPlayer = run {
        val audioAttributes = AudioAttributes.Builder()
            .setUsage(C.USAGE_MEDIA)
            .setContentType(C.AUDIO_CONTENT_TYPE_MOVIE)
            .build()

        ExoPlayer.Builder(
            context,
            DefaultRenderersFactory(context)
                .setExtensionRendererMode(DefaultRenderersFactory.EXTENSION_RENDERER_MODE_ON)
                .setEnableDecoderFallback(true)
                .setMediaCodecSelector(
                    if (hardwareDecode) MediaCodecSelector.DEFAULT else MediaCodecSelector.PREFER_SOFTWARE
                ),
        )
            .setAudioAttributes(audioAttributes, /* handleAudioFocus = */ true)
            .setHandleAudioBecomingNoisy(true)
            .setWakeMode(C.WAKE_MODE_NETWORK)
            .setLoadControl(
                DefaultLoadControl.Builder()
                    .setBufferDurationsMs(
                        MIN_BUFFER_MS,
                        MAX_BUFFER_MS,
                        BUFFER_FOR_PLAYBACK_MS,
                        BUFFER_FOR_PLAYBACK_AFTER_REBUFFER_MS,
                    )
                    .setBackBuffer(BACK_BUFFER_DURATION_MS, false)
                    .setPrioritizeTimeOverSizeThresholds(true)
                    .build(),
            )
            .build()
    }

    private val playerView = PlayerView(context).apply {
        layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT,
        )
        useController = false
        resizeMode = AspectRatioFrameLayout.RESIZE_MODE_FIT
        player = this@ExoPlayerSurfaceView.player
    }

    private val channel = MethodChannel(messenger, "stream_hub/exo_surface_$viewId")
    private val events = EventChannel(messenger, "stream_hub/exo_surface_events_$viewId")

    private val mainHandler = Handler(Looper.getMainLooper())

    private var eventSink: EventChannel.EventSink? = null
    private var disposed = false
    private var currentVolume = 1.0f
    private var muted = false
    private var lastLoadUrl: String = ""
    private var reconnectAttempts = 0

    // URL the pending reconnect belongs to; a new load invalidates it.
    private var reconnectTargetUrl: String? = null

    // Distinguishes "player READY" from "video actually rendering".
    private var renderedFirstFrame = false

    private val reconnectRunnable = Runnable { attemptReconnect() }

    private val renderWatchdogRunnable = Runnable {
        if (disposed || player.isReleased()) return@Runnable
        if (renderedFirstFrame || !player.playWhenReady || !hasVideoTrack()) return@Runnable
        if (player.playbackState != Player.STATE_READY) return@Runnable
        android.util.Log.e(
            NativePlaybackDiagnostics.TAG_SURFACE_VIEW,
            "render watchdog: READY+playing but no video frame rendered within ${RENDER_WATCHDOG_MS}ms " +
                "url=${NativePlaybackDiagnostics.sanitizeUrl(lastLoadUrl)}",
        )
        emitError(
            "No video output: player is ready but no frames are rendering.",
            NativePlaybackDiagnostics.ErrorCategory.RENDERER,
        )
    }

    private val playerListener = object : Player.Listener {
        override fun onPlaybackStateChanged(playbackState: Int) {
            when (playbackState) {
                Player.STATE_BUFFERING -> emitState("buffering")
                Player.STATE_READY -> {
                    if (reconnectAttempts > 0) reconnectAttempts = 0
                    emitState(if (player.playWhenReady) "playing" else "paused")
                    emitPosition()
                    armRenderWatchdogIfNeeded()
                }
                Player.STATE_ENDED -> {
                    mainHandler.removeCallbacks(renderWatchdogRunnable)
                    if (player.isCurrentMediaItemLive || player.duration == C.TIME_UNSET) {
                        reconnectTargetUrl = lastLoadUrl
                        if (!scheduleReconnect("Live stream socket ended")) {
                            emitState("completed")
                        }
                    } else {
                        emitState("completed")
                    }
                }
                Player.STATE_IDLE -> {
                    mainHandler.removeCallbacks(renderWatchdogRunnable)
                    emitState("idle")
                }
            }
        }

        override fun onIsPlayingChanged(isPlaying: Boolean) {
            if (player.playbackState == Player.STATE_READY) {
                emitState(if (isPlaying) "playing" else "paused")
            }
            if (isPlaying) armRenderWatchdogIfNeeded()
        }

        override fun onRenderedFirstFrame() {
            mainHandler.removeCallbacks(renderWatchdogRunnable)
            renderedFirstFrame = true
            android.util.Log.i(NativePlaybackDiagnostics.TAG_SURFACE_VIEW, "first video frame rendered")
        }

        override fun onPlayerError(error: PlaybackException) {
            mainHandler.removeCallbacks(reconnectRunnable)
            mainHandler.removeCallbacks(renderWatchdogRunnable)
            val classification = NativePlaybackDiagnostics.classify(error)
            android.util.Log.e(
                NativePlaybackDiagnostics.TAG_SURFACE_VIEW,
                "playback error category=${classification.category.wireName} " +
                    "httpCode=${classification.httpCode} code=${error.errorCode} " +
                    "url=${NativePlaybackDiagnostics.sanitizeUrl(lastLoadUrl)}: ${classification.friendlyMessage}",
                error,
            )
            if (error.errorCode == PlaybackException.ERROR_CODE_BEHIND_LIVE_WINDOW) {
                try {
                    player.seekToDefaultPosition()
                    player.prepare()
                } catch (_: Throwable) {}
                return
            }
            if (classification.category != NativePlaybackDiagnostics.ErrorCategory.NETWORK ||
                !scheduleReconnect(classification.friendlyMessage)
            ) {
                emitError(
                    classification.friendlyMessage,
                    classification.category,
                    classification.httpCode,
                )
            }
        }

        override fun onVideoSizeChanged(videoSize: VideoSize) {
            emitVideo(videoSize.width, videoSize.height)
        }
    }

    /**
     * Schedules a bounded backoff reconnect for transient network failures.
     * Returns false when the budget is exhausted and the error must surface.
     * playWhenReady is preserved so a paused stream stays paused after recovery.
     */
    private fun scheduleReconnect(friendlyMessage: String): Boolean {
        if (reconnectAttempts >= MAX_RECONNECT_ATTEMPTS) return false
        reconnectAttempts++
        reconnectTargetUrl = lastLoadUrl
        val delay =
            (RECONNECT_BASE_DELAY_MS shl (reconnectAttempts - 1)).coerceAtMost(RECONNECT_MAX_DELAY_MS)
        android.util.Log.w(
            NativePlaybackDiagnostics.TAG_SURFACE_VIEW,
            "transient network failure; reconnect attempt $reconnectAttempts/$MAX_RECONNECT_ATTEMPTS in ${delay}ms",
        )
        emitState("buffering")
        mainHandler.postDelayed(reconnectRunnable, delay)
        return true
    }

    private fun attemptReconnect() {
        if (disposed || player.isReleased()) return
        // Never resurrect a stream the user has already replaced.
        if (lastLoadUrl != reconnectTargetUrl) return
        try {
            if (player.playbackState == Player.STATE_ENDED || player.playbackState == Player.STATE_IDLE) {
                player.seekToDefaultPosition()
            }
            player.prepare()
            player.play()
        } catch (e: Throwable) {
            android.util.Log.e(NativePlaybackDiagnostics.TAG_SURFACE_VIEW, "reconnect prepare failed", e)
            emitError(
                "Network error: Unable to connect to stream server.",
                NativePlaybackDiagnostics.ErrorCategory.NETWORK,
            )
        }
    }

    private fun armRenderWatchdogIfNeeded() {
        mainHandler.removeCallbacks(renderWatchdogRunnable)
        if (renderedFirstFrame || !player.playWhenReady || !hasVideoTrack()) return
        if (player.playbackState != Player.STATE_READY) return
        mainHandler.postDelayed(renderWatchdogRunnable, RENDER_WATCHDOG_MS)
    }

    private fun hasVideoTrack(): Boolean =
        player.currentTracks.groups.any { it.type == C.TRACK_TYPE_VIDEO && it.length > 0 }

    private fun ExoPlayer.isReleased(): Boolean = try {
        currentPosition >= 0
    } catch (_: IllegalStateException) {
        true
    }

    private val streamHandler = object : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
            eventSink = events
            mainHandler.removeCallbacks(positionReporter)
            mainHandler.post(positionReporter)
            emitPosition()
        }

        override fun onCancel(arguments: Any?) {
            eventSink = null
            mainHandler.removeCallbacks(positionReporter)
        }
    }

    private val positionReporter = object : Runnable {
        override fun run() {
            emitPosition()
            mainHandler.postDelayed(this, POSITION_INTERVAL_MS)
        }
    }

    init {
        player.addListener(playerListener)
        channel.setMethodCallHandler(this)
        events.setStreamHandler(streamHandler)
    }

    // ---- Flutter events ----------------------------------------------------

    private fun emitState(state: String) {
        eventSink?.success(mapOf("type" to "state", "state" to state))
    }

    private fun emitPosition() {
        val sink = eventSink ?: return
        if (player.playbackState == Player.STATE_IDLE) return
        val duration = if (player.duration == C.TIME_UNSET) 0L else player.duration
        sink.success(
            mapOf(
                "type" to "position",
                "positionMs" to player.currentPosition,
                "bufferedMs" to player.bufferedPosition,
                "durationMs" to duration,
            )
        )
    }

    private fun emitError(
        message: String,
        category: NativePlaybackDiagnostics.ErrorCategory = NativePlaybackDiagnostics.ErrorCategory.UNKNOWN,
        httpCode: Int? = null,
    ) {
        eventSink?.success(
            mapOf(
                "type" to "error",
                "message" to message,
                "category" to category.wireName,
                "httpCode" to httpCode,
            )
        )
    }

    private fun emitVideo(width: Int, height: Int) {
        eventSink?.success(mapOf("type" to "video", "width" to width, "height" to height))
    }

    // ---- Method channel ----------------------------------------------------

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "dispose") {
            disposeInternal()
            result.success(null)
            return
        }
        if (disposed) {
            result.success(null)
            return
        }
        try {
            when (call.method) {
                "load" -> load(call, result)
                "play" -> {
                    if (player.playbackState == Player.STATE_ENDED || player.playbackState == Player.STATE_IDLE) {
                        player.seekToDefaultPosition()
                        player.prepare()
                    }
                    player.play()
                    result.success(null)
                }
                "pause" -> {
                    player.pause()
                    result.success(null)
                }
                "seekTo" -> {
                    val ms = (call.argument<Number>("positionMs") ?: 0L).toLong()
                    player.seekTo(ms)
                    result.success(null)
                }
                "setVolume" -> {
                    val volume = (call.argument<Number>("volume") ?: 1.0).toFloat().coerceIn(0f, 1f)
                    currentVolume = volume
                    player.volume = if (muted) 0f else volume
                    result.success(null)
                }
                "setMuted" -> {
                    muted = call.argument<Boolean>("muted") ?: false
                    player.volume = if (muted) 0f else currentVolume
                    result.success(null)
                }
                "setSpeed" -> {
                    val speed = (call.argument<Number>("speed") ?: 1.0).toFloat().coerceIn(0.25f, 4f)
                    player.playbackParameters = PlaybackParameters(speed)
                    result.success(null)
                }
                "setAspectRatio" -> {
                    applyAspectRatio(call.argument<String>("mode"))
                    result.success(null)
                }
                "stop" -> {
                    try {
                        player.stop()
                    } catch (_: Throwable) {}
                    result.success(null)
                }
                "getBufferInfo" -> {
                    result.success(
                        mapOf(
                            "bufferedMs" to player.bufferedPosition,
                            "durationMs" to (if (player.duration == C.TIME_UNSET) 0L else player.duration),
                        )
                    )
                }
                "getAvailableAudioTracks" -> result.success(tracksOf(C.TRACK_TYPE_AUDIO))
                "getAvailableSubtitleTracks" -> result.success(tracksOf(C.TRACK_TYPE_TEXT))
                "getAvailableQualities" -> result.success(qualities())
                "setAudioTrack" -> selectTrack(call.argument<String>("trackId"), C.TRACK_TYPE_AUDIO, result)
                "setSubtitleTrack" -> selectTrack(call.argument<String>("trackId"), C.TRACK_TYPE_TEXT, result)
                "setQuality" -> selectQuality(call.argument<String>("quality"), result)
                else -> result.notImplemented()
            }
        } catch (_: Throwable) {
            result.success(null)
        }
    }

    private fun load(call: MethodCall, result: MethodChannel.Result) {
        val url = call.argument<String>("url")
        if (url.isNullOrEmpty()) {
            result.error("invalid_args", "Missing stream URL", null)
            return
        }
        val uri = Uri.parse(url)
        if (!uri.isAbsolute) {
            result.error("invalid_args", "Stream URL is not absolute: $url", null)
            return
        }
        val headers = call.argument<Map<String, String>>("headers") ?: emptyMap()
        val seekToMs = (call.argument<Number>("seekToMs") ?: 0L).toLong()
        val mimeType = call.argument<String>("mimeType")

        try {
            // New load is an explicit action: reset any pending reconnect budget
            // and the first-frame watchdog state.
            mainHandler.removeCallbacks(reconnectRunnable)
            mainHandler.removeCallbacks(renderWatchdogRunnable)
            reconnectAttempts = 0
            reconnectTargetUrl = url
            renderedFirstFrame = false
            lastLoadUrl = url

            val httpDataSourceFactory = buildHttpDataSourceFactory(headers)
            val mediaItem = MediaItem.Builder().setUri(uri).build()

            // IPTV MPEG-TS robustness flags (mirrors NativePlayerActivity):
            // tolerate non-IDR keyframes, detect access units, enable DTS audio
            // and ignore splice info so difficult TS relays demux cleanly.
            val extractorsFactory = DefaultExtractorsFactory().apply {
                setTsExtractorFlags(
                    DefaultTsPayloadReaderFactory.FLAG_ALLOW_NON_IDR_KEYFRAMES or
                    DefaultTsPayloadReaderFactory.FLAG_DETECT_ACCESS_UNITS or
                    DefaultTsPayloadReaderFactory.FLAG_ENABLE_HDMV_DTS_AUDIO_STREAMS or
                    DefaultTsPayloadReaderFactory.FLAG_IGNORE_SPLICE_INFO_STREAM,
                )
                setConstantBitrateSeekingEnabled(true)
            }

            val mediaSource: MediaSource = when (Util.inferContentType(uri, mimeType ?: "")) {
                C.CONTENT_TYPE_HLS -> HlsMediaSource.Factory(httpDataSourceFactory)
                    .createMediaSource(mediaItem)
                C.CONTENT_TYPE_DASH -> DashMediaSource.Factory(httpDataSourceFactory)
                    .createMediaSource(mediaItem)
                C.CONTENT_TYPE_RTSP -> RtspMediaSource.Factory().createMediaSource(mediaItem)
                else -> ProgressiveMediaSource.Factory(httpDataSourceFactory, extractorsFactory)
                    .createMediaSource(mediaItem)
            }
            player.setMediaSource(mediaSource)
            player.prepare()
            if (seekToMs > 0) player.seekTo(seekToMs)
            player.playWhenReady = false
            result.success(null)
        } catch (e: Exception) {
            result.error("load_failed", "Failed to load stream: ${e.message}", null)
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

        // Route explicit Cookie headers through the shared java.net CookieHandler
        // so they are attached to playlist, segment and key requests alike
        // (mirrors NativePlayerActivity).
        try {
            val cookieManager = (java.net.CookieHandler.getDefault() as? java.net.CookieManager)
                ?: java.net.CookieManager(null, java.net.CookiePolicy.ACCEPT_ALL).also {
                    java.net.CookieHandler.setDefault(it)
                }
            val cookieVal = headers["Cookie"] ?: headers["cookie"]
            if (!cookieVal.isNullOrBlank() && lastLoadUrl.isNotBlank()) {
                val uriObj = java.net.URI(lastLoadUrl)
                for (part in cookieVal.split(";")) {
                    val trimmed = part.trim()
                    if (trimmed.isNotBlank()) {
                        try {
                            for (c in java.net.HttpCookie.parse(trimmed)) {
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

    private fun applyAspectRatio(mode: String?) {
        val resizeMode = when (mode) {
            "fill", "stretch" -> AspectRatioFrameLayout.RESIZE_MODE_FILL
            "zoom" -> AspectRatioFrameLayout.RESIZE_MODE_ZOOM
            else -> AspectRatioFrameLayout.RESIZE_MODE_FIT
        }
        playerView.resizeMode = resizeMode
        val scalingMode = when (mode) {
            "fill", "zoom" -> C.VIDEO_SCALING_MODE_SCALE_TO_FIT_WITH_CROPPING
            else -> C.VIDEO_SCALING_MODE_DEFAULT
        }
        player.setVideoScalingMode(scalingMode)
    }

    private fun tracksOf(trackType: Int): List<Map<String, Any>> {
        val tracks = mutableListOf<Map<String, Any>>()
        for (group in player.currentTracks.groups) {
            if (group.type != trackType) continue
            val trackGroup = group.mediaTrackGroup
            for (i in 0 until trackGroup.length) {
                val format = trackGroup.getFormat(i)
                tracks.add(
                    mapOf(
                        "id" to "${trackGroup.hashCode()}:$i",
                        "label" to (format.label ?: format.language ?: "Track $i"),
                        "language" to (format.language ?: ""),
                    )
                )
            }
        }
        return tracks
    }

    private fun selectTrack(trackId: String?, trackType: Int, result: MethodChannel.Result) {
        if (trackId.isNullOrEmpty()) {
            result.error("invalid_args", "Missing track id", null)
            return
        }
        for (group in player.currentTracks.groups) {
            if (group.type != trackType) continue
            val trackGroup = group.mediaTrackGroup
            for (i in 0 until trackGroup.length) {
                if ("${trackGroup.hashCode()}:$i" == trackId) {
                    val override = TrackSelectionOverride(trackGroup, i)
                    player.setTrackSelectionParameters(
                        player.trackSelectionParameters.buildUpon()
                            .setOverrideForType(override)
                            .build()
                    )
                    result.success(null)
                    return
                }
            }
        }
        result.error("track_not_found", "Track not found: $trackId", null)
    }

    private fun qualities(): List<Map<String, Any>> {
        val qualities = mutableListOf<Map<String, Any>>(mapOf("quality" to "auto"))
        for (group in player.currentTracks.groups) {
            if (group.type != C.TRACK_TYPE_VIDEO) continue
            val trackGroup = group.mediaTrackGroup
            for (i in 0 until trackGroup.length) {
                val height = trackGroup.getFormat(i).height
                val label = when {
                    height >= 2160 -> "4K"
                    height >= 1080 -> "1080p"
                    height >= 720 -> "720p"
                    height >= 480 -> "480p"
                    height >= 360 -> "360p"
                    else -> "Auto"
                }
                if (qualities.none { it["quality"] == label }) {
                    qualities.add(
                        mapOf(
                            "quality" to label,
                            "height" to height,
                            "id" to "${trackGroup.hashCode()}:$i",
                        )
                    )
                }
            }
        }
        return qualities
    }

    private fun selectQuality(quality: String?, result: MethodChannel.Result) {
        if (quality == null || quality == "auto") {
            player.setTrackSelectionParameters(
                player.trackSelectionParameters.buildUpon().clearOverrides().build()
            )
            result.success(null)
            return
        }
        val targetHeight = when (quality) {
            "4K" -> 2160
            "1080p" -> 1080
            "720p" -> 720
            "480p" -> 480
            "360p" -> 360
            else -> -1
        }
        if (targetHeight <= 0) {
            result.error("invalid_quality", "Unknown quality: $quality", null)
            return
        }
        for (group in player.currentTracks.groups) {
            if (group.type != C.TRACK_TYPE_VIDEO) continue
            val trackGroup = group.mediaTrackGroup
            for (i in 0 until trackGroup.length) {
                if (trackGroup.getFormat(i).height == targetHeight) {
                    val override = TrackSelectionOverride(trackGroup, i)
                    player.setTrackSelectionParameters(
                        player.trackSelectionParameters.buildUpon()
                            .setOverrideForType(override)
                            .build()
                    )
                    result.success(null)
                    return
                }
            }
        }
        result.error("quality_not_found", "Quality not available: $quality", null)
    }

    private fun disposeInternal() {
        if (disposed) return
        disposed = true
        mainHandler.removeCallbacksAndMessages(null)
        channel.setMethodCallHandler(null)
        events.setStreamHandler(null)
        eventSink = null
        player.removeListener(playerListener)
        player.release()
    }

    override fun dispose() {
        disposeInternal()
    }

    override fun getView(): View = playerView
}
