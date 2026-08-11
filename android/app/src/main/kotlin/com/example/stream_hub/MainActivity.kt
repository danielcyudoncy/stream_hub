package com.example.stream_hub

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Registers the native ExoPlayer SurfaceView platform view used by the
        // ExoPlayerSurfaceViewAdapter. The view is composed by SurfaceFlinger
        // in hybrid-composition mode, bypassing Flutter's external-texture GL
        // sampler (the path that black-screens on Unisoc/Mali devices).
        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory(
                ExoPlayerSurfaceView.viewType,
                ExoPlayerSurfaceViewFactory(flutterEngine.dartExecutor.binaryMessenger),
            )

        // Lets the NativeActivityPlayerAdapter launch the fullscreen native
        // video Activity (NativePlayerActivity). That Activity renders ExoPlayer
        // through a plain TextureView outside the Flutter view hierarchy, which
        // is the only render path that displays video on Unisoc/Mali devices
        // (see docs/PLAYBACK_ENGINEERING.md §8.3).
        NativePlayerActivity.messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "stream_hub/native_player_launch",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getDeviceHardwareInfo" -> {
                    val info = mapOf(
                        "hardware" to android.os.Build.HARDWARE,
                        "board" to android.os.Build.BOARD,
                        "manufacturer" to android.os.Build.MANUFACTURER,
                        "brand" to android.os.Build.BRAND,
                        "model" to android.os.Build.MODEL
                    )
                    result.success(info)
                }
                "launch" -> {
                    val url = call.argument<String>("url")
                    if (url.isNullOrEmpty()) {
                        result.error("invalid_args", "Missing stream URL", null)
                        return@setMethodCallHandler
                    }
                    val headers = call.argument<Map<String, String>>("headers") ?: emptyMap()
                    NativePlayerActivity.launch(this, url, headers)
                    result.success(null)
                }
                "stop" -> {
                    NativePlayerActivity.instance?.finish()
                    result.success(null)
                }
                "play" -> {
                    NativePlayerActivity.instance?.playCommand()
                    result.success(null)
                }
                "pause" -> {
                    NativePlayerActivity.instance?.pauseCommand()
                    result.success(null)
                }
                "seekTo" -> {
                    val ms = (call.argument<Number>("positionMs") ?: 0L).toLong()
                    NativePlayerActivity.instance?.seekTo(ms)
                    result.success(null)
                }
                "setVolume" -> {
                    NativePlayerActivity.instance
                        ?.setVolumeCommand((call.argument<Number>("volume") ?: 1.0).toFloat())
                    result.success(null)
                }
                "setMuted" -> {
                    NativePlayerActivity.instance
                        ?.setMutedCommand(call.argument<Boolean>("muted") ?: false)
                    result.success(null)
                }
                "setSpeed" -> {
                    NativePlayerActivity.instance
                        ?.setSpeed((call.argument<Number>("speed") ?: 1.0).toFloat())
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
