package com.example.stream_hub

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Creates [ExoPlayerSurfaceView] platform views for the
 * `com.example.stream_hub/exo_surface` view type.
 *
 * The factory is registered in [MainActivity.configureFlutterEngine] using the
 * engine's binary messenger so each created view can open its own method and
 * event channels (namespaced by view id).
 */
class ExoPlayerSurfaceViewFactory(
    private val messenger: BinaryMessenger,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *>
        val hardwareDecode = params?.get("hardwareDecode") as? Boolean ?: true
        return ExoPlayerSurfaceView(context, messenger, viewId, hardwareDecode)
    }
}
