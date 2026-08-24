package com.example.stream_hub

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Registers the experimental IJK launch MethodChannel
 * (`stream_hub/ijk_player_launch`).
 *
 * This is kept in its own source file inside `src/ijk/kotlin` so the whole IJK
 * surface can be compiled out when the vendored ijkplayer AAR is absent (see
 * `build.gradle.kts` and docs/IJK_EVALUATION.md). [MainActivity] calls
 * [register] through reflection, so it has no static dependency on IJK when the
 * engine is unavailable — the rest of the app still builds and runs.
 */
object IjkPlayerLaunch {
    @JvmStatic
    fun register(context: android.content.Context, flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "stream_hub/ijk_player_launch",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "launch" -> {
                    val url = call.argument<String>("url")
                    if (url.isNullOrEmpty()) {
                        result.error("invalid_args", "Missing stream URL", null)
                        return@setMethodCallHandler
                    }
                    val headers = call.argument<Map<String, String>>("headers") ?: emptyMap()
                    val title = call.argument<String>("title")
                    val isLive = call.argument<Boolean>("isLive") ?: false

                    val active = IjkPlayerActivity.instance
                    if (active != null && !active.isFinishing && !active.isDestroyed) {
                        active.loadStream(url, headers, title, isLive)
                        result.success(null)
                        return@setMethodCallHandler
                    }

                    IjkPlayerActivity.launch(context, url, headers, title, isLive)
                    result.success(null)
                }
                "play" -> {
                    IjkPlayerActivity.instance?.playCommand()
                    result.success(null)
                }
                "pause" -> {
                    IjkPlayerActivity.instance?.pauseCommand()
                    result.success(null)
                }
                "stop" -> {
                    IjkPlayerActivity.instance?.stopCommand()
                    result.success(null)
                }
                "seekTo" -> {
                    val ms = (call.argument<Number>("positionMs") ?: 0L).toLong()
                    IjkPlayerActivity.instance?.seekTo(ms)
                    result.success(null)
                }
                "setVolume" -> {
                    IjkPlayerActivity.instance
                        ?.setVolumeCommand((call.argument<Number>("volume") ?: 1.0).toFloat())
                    result.success(null)
                }
                "setMuted" -> {
                    IjkPlayerActivity.instance
                        ?.setMutedCommand(call.argument<Boolean>("muted") ?: false)
                    result.success(null)
                }
                "setSpeed" -> {
                    IjkPlayerActivity.instance
                        ?.setSpeedCommand((call.argument<Number>("speed") ?: 1.0).toFloat())
                    result.success(null)
                }
                "reload" -> {
                    IjkPlayerActivity.instance?.reloadCommand()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
