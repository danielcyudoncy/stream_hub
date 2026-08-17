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
        // through a plain SurfaceView outside the Flutter view hierarchy, which
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
                    val title = call.argument<String>("title")
                    val channelsRaw = call.argument<List<Map<String, Any?>>>("channels")
                    val channels = channelsRaw?.mapNotNull { item ->
                        val id = item["id"] as? String ?: return@mapNotNull null
                        val name = item["name"] as? String ?: return@mapNotNull null
                        val streamUrl = item["url"] as? String ?: return@mapNotNull null
                        val logoUrl = item["logoUrl"] as? String
                        val epgTitle = item["epgTitle"] as? String
                        val category = item["category"] as? String
                        val itemHeaders = (item["headers"] as? Map<*, *>)
                            ?.entries
                            ?.associate { it.key.toString() to it.value.toString() }
                            ?: emptyMap()
                        NativeChannelItem(
                            id = id,
                            name = name,
                            url = streamUrl,
                            logoUrl = logoUrl,
                            epgTitle = epgTitle,
                            category = category,
                            headers = itemHeaders,
                        )
                    }
                    val channelIndex = call.argument<Int>("channelIndex") ?: -1
                    val isLive = call.argument<Boolean>("isLive") ?: false

                    val active = NativePlayerActivity.instance
                    if (active != null && !active.isFinishing && !active.isDestroyed) {
                        channels?.let { NativePlayerActivity.channelList = it }
                        if (channelIndex >= 0) NativePlayerActivity.currentChannelIndex = channelIndex
                        active.updateChannels(channels, channelIndex)
                        active.loadStream(url, headers, title, null)
                        result.success(null)
                        return@setMethodCallHandler
                    }

                    NativePlayerActivity.launch(this, url, headers, title, channels, channelIndex, isLive)
                    result.success(null)
                }
                "setChannelList" -> {
                    val channelsRaw = call.argument<List<Map<String, Any?>>>("channels")
                    val channelIndex = call.argument<Int>("channelIndex") ?: -1
                    val channels = channelsRaw?.mapNotNull { item ->
                        val id = item["id"] as? String ?: return@mapNotNull null
                        val name = item["name"] as? String ?: return@mapNotNull null
                        val streamUrl = item["url"] as? String ?: return@mapNotNull null
                        val logoUrl = item["logoUrl"] as? String
                        val epgTitle = item["epgTitle"] as? String
                        val category = item["category"] as? String
                        val itemHeaders = (item["headers"] as? Map<*, *>)
                            ?.entries
                            ?.associate { it.key.toString() to it.value.toString() }
                            ?: emptyMap()
                        NativeChannelItem(
                            id = id,
                            name = name,
                            url = streamUrl,
                            logoUrl = logoUrl,
                            epgTitle = epgTitle,
                            category = category,
                            headers = itemHeaders,
                        )
                    }
                    channels?.let { NativePlayerActivity.channelList = it }
                    if (channelIndex >= 0) {
                        NativePlayerActivity.currentChannelIndex = channelIndex
                    }
                    NativePlayerActivity.instance?.updateChannels(channels, channelIndex)
                    result.success(null)
                }
                "enterPip" -> {
                    NativePlayerActivity.instance?.enterPipMode()
                    result.success(null)
                }
                "nextChannel" -> {
                    NativePlayerActivity.instance?.nextChannel()
                    result.success(null)
                }
                "previousChannel" -> {
                    NativePlayerActivity.instance?.previousChannel()
                    result.success(null)
                }
                "switchChannel" -> {
                    val index = call.argument<Int>("index") ?: 0
                    NativePlayerActivity.instance?.switchChannelByIndex(index)
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
