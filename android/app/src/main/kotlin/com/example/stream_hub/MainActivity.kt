package com.example.stream_hub

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

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
        // through a plain window-owned TextureView outside the Flutter view
        // hierarchy, which is the render path proven to display video on
        // Unisoc/Mali devices (see docs/PLAYBACK_ENGINEERING.md §8.3).
        NativePlayerActivity.messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "stream_hub/native_player_launch",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isTelevision" -> {
                    val uiModeManager = getSystemService(android.content.Context.UI_MODE_SERVICE) as? android.app.UiModeManager
                    val isTvMode = uiModeManager?.currentModeType == android.content.res.Configuration.UI_MODE_TYPE_TELEVISION
                    val hasLeanback = packageManager.hasSystemFeature(android.content.pm.PackageManager.FEATURE_LEANBACK)
                    val hasTelevision = packageManager.hasSystemFeature(android.content.pm.PackageManager.FEATURE_TELEVISION)
                    val noTouch = !packageManager.hasSystemFeature(android.content.pm.PackageManager.FEATURE_TOUCHSCREEN)
                    val modelLower = android.os.Build.MODEL.lowercase()
                    val productLower = android.os.Build.PRODUCT.lowercase()
                    val isTvBoxModel = modelLower.contains("tv") || modelLower.contains("box") ||
                                       productLower.contains("tv") || productLower.contains("box") ||
                                       productLower.contains("droidlogic") || productLower.contains("amlogic")
                    val isTv = isTvMode || hasLeanback || hasTelevision || noTouch || isTvBoxModel
                    result.success(isTv)
                }
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

        // Dedicated hardware device controls channel for on-screen player gestures
        // (Window backlight brightness and AudioManager STREAM_MUSIC volume).
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "stream_hub/device_controls",
        ).setMethodCallHandler { call, result ->
            val audioManager = getSystemService(android.content.Context.AUDIO_SERVICE) as? android.media.AudioManager
            when (call.method) {
                "getVolume" -> {
                    if (audioManager != null) {
                        val maxVol = audioManager.getStreamMaxVolume(android.media.AudioManager.STREAM_MUSIC).coerceAtLeast(1)
                        val curVol = audioManager.getStreamVolume(android.media.AudioManager.STREAM_MUSIC)
                        result.success(curVol.toDouble() / maxVol.toDouble())
                    } else {
                        result.success(1.0)
                    }
                }
                "setVolume" -> {
                    val volumeRatio = (call.argument<Number>("volume") ?: 1.0).toDouble().coerceIn(0.0, 1.0)
                    if (audioManager != null) {
                        val maxVol = audioManager.getStreamMaxVolume(android.media.AudioManager.STREAM_MUSIC).coerceAtLeast(1)
                        val targetVol = (volumeRatio * maxVol).toInt().coerceIn(0, maxVol)
                        // 0 = flags (no system HUD popup to prevent duplicate UI over our custom HUD)
                        audioManager.setStreamVolume(android.media.AudioManager.STREAM_MUSIC, targetVol, 0)
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                "getBrightness" -> {
                    val lp = window.attributes
                    val curBrightness = lp.screenBrightness
                    if (curBrightness >= 0f) {
                        result.success(curBrightness.toDouble())
                    } else {
                        // -1.0 means default system brightness; query ContentResolver or return 0.5 default
                        try {
                            val sysBrightness = android.provider.Settings.System.getInt(
                                contentResolver,
                                android.provider.Settings.System.SCREEN_BRIGHTNESS,
                                128
                            )
                            result.success(sysBrightness.toDouble() / 255.0)
                        } catch (_: Throwable) {
                            result.success(0.5)
                        }
                    }
                }
                "setBrightness" -> {
                    val brightness = (call.argument<Number>("brightness") ?: 1.0).toDouble().coerceIn(0.01, 1.0)
                    val lp = window.attributes
                    lp.screenBrightness = brightness.toFloat()
                    window.attributes = lp
                    result.success(true)
                }
                "restoreBrightness" -> {
                    val lp = window.attributes
                    lp.screenBrightness = android.view.WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
                    window.attributes = lp
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "stream_hub/app_update",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath.isNullOrEmpty()) {
                        result.error("invalid_path", "APK path is empty", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val file = File(filePath)
                        if (!file.exists()) {
                            result.error("file_not_found", "APK file does not exist at $filePath", null)
                            return@setMethodCallHandler
                        }
                        val context = applicationContext
                        val uri = FileProvider.getUriForFile(
                            context,
                            "${context.packageName}.fileprovider",
                            file,
                        )
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        context.startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("install_error", e.message, null)
                    }
                }
                "canRequestPackageInstalls" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        result.success(packageManager.canRequestPackageInstalls())
                    } else {
                        result.success(true)
                    }
                }
                "openInstallPermissionSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        try {
                            val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("settings_error", e.message, null)
                        }
                    } else {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Phase 3 evaluation engine (docs/PLAYBACK_ENGINEERING.md §10): the
        // IJK launch channel is registered by IjkPlayerLaunch, which lives in
        // the optional `src/ijk/kotlin` source set. We register it via
        // reflection so this Activity has no static dependency on IJK when the
        // vendored ijkplayer AAR is absent (the engine is then compiled out and
        // the call silently no-ops).
        try {
            val launchClass =
                Class.forName("com.example.stream_hub.IjkPlayerLaunch")
            launchClass
                .getMethod("register", android.content.Context::class.java, FlutterEngine::class.java)
                .invoke(null, this, flutterEngine)
        } catch (_: Throwable) {
            // IJK not compiled into this build; ignore.
        }
    }
}
