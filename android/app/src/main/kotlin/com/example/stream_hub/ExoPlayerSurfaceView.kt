package com.example.stream_hub

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.view.TextureView
import android.view.View
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
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.dash.DashMediaSource
import androidx.media3.exoplayer.hls.HlsMediaSource
import androidx.media3.exoplayer.mediacodec.MediaCodecSelector
import androidx.media3.exoplayer.rtsp.RtspMediaSource
import androidx.media3.exoplayer.source.MediaSource
import androidx.media3.exoplayer.source.ProgressiveMediaSource
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView

/**
 * Android platform view that hosts an ExoPlayer (Media3) backend rendered
 * through a [TextureView].
 *
 * Render path: ExoPlayer's MediaCodec pipeline renders into the Surface
 * backed by this TextureView. The TextureView is a regular view in the
 * Android hierarchy, so it is composited natively without the separate
 * SurfaceFlinger layer SurfaceView introduces. SurfaceView misbehaves inside
 * Flutter hybrid-composition platform views on Unisoc/Mali devices (video
 * decodes but never becomes visible), while TextureView is the same approach
 * used by flutter_vlc_player's VLCTextureView.
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
    }

    private val textureView = TextureView(context).apply {
        layoutParams = android.widget.FrameLayout.LayoutParams(
            android.widget.FrameLayout.LayoutParams.MATCH_PARENT,
            android.widget.FrameLayout.LayoutParams.MATCH_PARENT,
        )
    }

    private val player: ExoPlayer = ExoPlayer.Builder(
        context,
        DefaultRenderersFactory(context)
            .setEnableDecoderFallback(true)
            .setMediaCodecSelector(
                if (hardwareDecode) MediaCodecSelector.DEFAULT else MediaCodecSelector.PREFER_SOFTWARE
            ),
    ).build()

    private val channel = MethodChannel(messenger, "stream_hub/exo_surface_$viewId")
    private val events = EventChannel(messenger, "stream_hub/exo_surface_events_$viewId")

    private val mainHandler = Handler(Looper.getMainLooper())

    private var eventSink: EventChannel.EventSink? = null
    private var disposed = false
    private var currentVolume = 1.0f
    private var muted = false

    private val playerListener = object : Player.Listener {
        override fun onPlaybackStateChanged(playbackState: Int) {
            when (playbackState) {
                Player.STATE_BUFFERING -> emitState("buffering")
                Player.STATE_READY -> {
                    emitState(if (player.playWhenReady) "playing" else "paused")
                    emitPosition()
                }
                Player.STATE_ENDED -> emitState("completed")
                Player.STATE_IDLE -> emitState("idle")
            }
        }

        override fun onIsPlayingChanged(isPlaying: Boolean) {
            if (player.playbackState == Player.STATE_READY) {
                emitState(if (isPlaying) "playing" else "paused")
            }
        }

        override fun onPlayerError(error: PlaybackException) {
            emitError("${error.errorCodeName}: ${error.message}")
        }

        override fun onVideoSizeChanged(videoSize: VideoSize) {
            emitVideo(videoSize.width, videoSize.height)
        }
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
        player.setVideoTextureView(textureView)
        player.setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(C.USAGE_MEDIA)
                .setContentType(C.AUDIO_CONTENT_TYPE_MOVIE)
                .build(),
            true,
        )
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

    private fun emitError(message: String) {
        eventSink?.success(mapOf("type" to "error", "message" to message))
    }

    private fun emitVideo(width: Int, height: Int) {
        eventSink?.success(mapOf("type" to "video", "width" to width, "height" to height))
    }

    // ---- Method channel ----------------------------------------------------

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "load" -> load(call, result)
            "play" -> {
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
                player.stop()
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
            "dispose" -> {
                disposeInternal()
                result.success(null)
            }
            else -> result.notImplemented()
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
            val httpDataSourceFactory = buildHttpDataSourceFactory(headers)
            val mediaItem = MediaItem.Builder().setUri(uri).build()
            val mediaSource: MediaSource = when (Util.inferContentType(uri, mimeType ?: "")) {
                C.CONTENT_TYPE_HLS -> HlsMediaSource.Factory(httpDataSourceFactory)
                    .createMediaSource(mediaItem)
                C.CONTENT_TYPE_DASH -> DashMediaSource.Factory(httpDataSourceFactory)
                    .createMediaSource(mediaItem)
                C.CONTENT_TYPE_RTSP -> RtspMediaSource.Factory().createMediaSource(mediaItem)
                else -> ProgressiveMediaSource.Factory(httpDataSourceFactory)
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
        return DefaultHttpDataSource.Factory()
            .setUserAgent(userAgent)
            .setDefaultRequestProperties(requestProperties)
            .setAllowCrossProtocolRedirects(true)
            .setConnectTimeoutMs(CONNECT_TIMEOUT_MS)
            .setReadTimeoutMs(READ_TIMEOUT_MS)
    }

    private fun applyAspectRatio(mode: String?) {
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
        mainHandler.removeCallbacks(positionReporter)
        channel.setMethodCallHandler(null)
        events.setStreamHandler(null)
        eventSink = null
        player.removeListener(playerListener)
        player.release()
    }

    override fun dispose() {
        disposeInternal()
    }

    override fun getView(): View = textureView
}
