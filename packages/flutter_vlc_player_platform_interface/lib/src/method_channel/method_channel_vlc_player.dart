import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_vlc_player_platform_interface/flutter_vlc_player_platform_interface.dart';
import 'package:flutter_vlc_player_platform_interface/src/messages/messages.dart';

/// An implementation of [VlcPlayerPlatform] that uses method channels.
class MethodChannelVlcPlayer extends VlcPlayerPlatform {
  final _api = VlcPlayerApi();

  EventChannel _mediaEventChannelFor(int viewId) {
    return EventChannel('flutter_video_plugin/getVideoEvents_$viewId');
  }

  EventChannel _rendererEventChannelFor(int viewId) {
    return EventChannel('flutter_video_plugin/getRendererEvents_$viewId');
  }

  @override
  Future<void> init() async {
    return _api.initialize();
  }

  @override
  Future<void> create({
    required int viewId,
    required String uri,
    required DataSourceType type,
    String? package,
    bool? autoPlay,
    HwAcc? hwAcc,
    VlcPlayerOptions? options,
  }) async {
    return _api.create(
      CreateMessage(
        playerId: viewId,
        uri: uri,
        type: type.index,
        packageName: package,
        autoPlay: autoPlay ?? true,
        hwAcc: hwAcc?.index,
        options: options?.get() ?? [],
      ),
    );
  }

  // ignore: proper_super_calls
  @override
  Future<void> dispose(int viewId) async {
    return _api.dispose(viewId);
  }

  /// This method builds the appropriate platform view where the player
  /// can be rendered.
  /// The `viewId` is passed as a parameter from the framework on the
  /// `onPlatformViewCreated` callback.
  ///
  /// The `virtualDisplay` specifies whether Virtual displays or Hybrid composition is used on Android.
  /// iOS only uses Hybrid composition.
  @override
  Widget buildView(
    PlatformViewCreatedCallback onPlatformViewCreated, {
    bool virtualDisplay = true,
  }) {
    const viewType = 'flutter_video_plugin/getVideoView';
    if (Platform.isAndroid) {
      return virtualDisplay
          ? AndroidView(
            viewType: viewType,
            hitTestBehavior: PlatformViewHitTestBehavior.transparent,
            onPlatformViewCreated: onPlatformViewCreated,
            creationParamsCodec: const StandardMessageCodec(),
          )
          : PlatformViewLink(
            viewType: viewType,
            surfaceFactory: (
              BuildContext _,
              PlatformViewController controller,
            ) {
              return AndroidViewSurface(
                controller: controller as AndroidViewController,
                gestureRecognizers: const {},
                hitTestBehavior: PlatformViewHitTestBehavior.transparent,
              );
            },
            onCreatePlatformView: (PlatformViewCreationParams params) {
              return PlatformViewsService.initSurfaceAndroidView(
                  id: params.id,
                  viewType: viewType,
                  layoutDirection: TextDirection.ltr,
                  creationParamsCodec: const StandardMessageCodec(),
                )
                ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
                ..addOnPlatformViewCreatedListener(onPlatformViewCreated)
                ..create();
            },
          );
    } else if (Platform.isIOS) {
      return UiKitView(
        viewType: viewType,
        onPlatformViewCreated: onPlatformViewCreated,
        hitTestBehavior: PlatformViewHitTestBehavior.transparent,
        creationParamsCodec: const StandardMessageCodec(),
      );
    }

    return const Text('Requested platform is not yet supported by this plugin');
  }

  @override
  // ignore: cyclomatic_complexity
  Stream<VlcMediaEvent> mediaEventsFor(int viewId) {
    return _mediaEventChannelFor(viewId).receiveBroadcastStream().map((
      dynamic event,
    ) {
      final Map<Object?, Object?> map = event as Map<Object?, Object?>;
      //
      switch (map['event']) {
        case 'opening':
          return VlcMediaEvent(mediaEventType: VlcMediaEventType.opening);

        case 'paused':
          return VlcMediaEvent(mediaEventType: VlcMediaEventType.paused);

        case 'stopped':
          return VlcMediaEvent(mediaEventType: VlcMediaEventType.stopped);

        case 'playing':
          return VlcMediaEvent(
            mediaEventType: VlcMediaEventType.playing,
            size: Size(
              (map['width'] as num?)?.toDouble() ?? 0.0,
              (map['height'] as num?)?.toDouble() ?? 0.0,
            ),
            playbackSpeed: map['speed'] as double? ?? 1.0,
            duration: Duration(milliseconds: map['duration'] as int? ?? 0),
            audioTracksCount: map['audioTracksCount'] as int? ?? 1,
            activeAudioTrack: map['activeAudioTrack'] as int? ?? 0,
            spuTracksCount: map['spuTracksCount'] as int? ?? 0,
            activeSpuTrack: map['activeSpuTrack'] as int? ?? -1,
          );

        case 'ended':
          return VlcMediaEvent(
            mediaEventType: VlcMediaEventType.ended,
            position: Duration(milliseconds: map['position'] as int? ?? 0),
          );

        case 'buffering':
        case 'timeChanged':
          const defaultBufferPercent = 100.0;

          return VlcMediaEvent(
            mediaEventType: VlcMediaEventType.timeChanged,
            size: Size(
              (map['width'] as num?)?.toDouble() ?? 0.0,
              (map['height'] as num?)?.toDouble() ?? 0.0,
            ),
            playbackSpeed: map['speed'] as double? ?? 1.0,
            position: Duration(milliseconds: map['position'] as int? ?? 0),
            duration: Duration(milliseconds: map['duration'] as int? ?? 0),
            audioTracksCount: map['audioTracksCount'] as int? ?? 1,
            activeAudioTrack: map['activeAudioTrack'] as int? ?? 0,
            spuTracksCount: map['spuTracksCount'] as int? ?? 0,
            activeSpuTrack: map['activeSpuTrack'] as int? ?? -1,
            bufferPercent: map['buffer'] as double? ?? defaultBufferPercent,
            isPlaying: map['isPlaying'] as bool? ?? false,
          );

        case 'mediaChanged':
          return VlcMediaEvent(mediaEventType: VlcMediaEventType.mediaChanged);

        case 'recording':
          return VlcMediaEvent(
            mediaEventType: VlcMediaEventType.recording,
            isRecording: map['isRecording'] as bool? ?? false,
            recordPath: map['recordPath'] as String? ?? '',
          );

        case 'error':
          return VlcMediaEvent(mediaEventType: VlcMediaEventType.error);

        default:
          return VlcMediaEvent(mediaEventType: VlcMediaEventType.unknown);
      }
    });
  }

  @override
  Future<void> setStreamUrl(
    int viewId, {
    required String uri,
    required DataSourceType type,
    String? package,
    bool? autoPlay,
    HwAcc? hwAcc,
  }) async {
    return _api.setStreamUrl(
      SetMediaMessage(
        playerId: viewId,
        uri: uri,
        type: type.index,
        packageName: package,
        autoPlay: autoPlay ?? true,
        hwAcc: hwAcc?.index,
      ),
    );
  }

  @override
  Future<void> setLooping(int viewId, bool looping) async {
    return _api.setLooping(viewId, looping);
  }

  @override
  Future<void> play(int viewId) async {
    return _api.play(viewId);
  }

  @override
  Future<void> pause(int viewId) async {
    return _api.pause(viewId);
  }

  @override
  Future<void> stop(int viewId) async {
    return _api.stop(viewId);
  }

  @override
  Future<bool?> isPlaying(int viewId) async {
    return _api.isPlaying(viewId);
  }

  @override
  Future<bool?> isSeekable(int viewId) async {
    return _api.isSeekable(viewId);
  }

  @override
  Future<void> seekTo(int viewId, Duration position) async {
    return _api.seekTo(viewId, position.inMilliseconds);
  }

  @override
  Future<Duration> getPosition(int viewId) async {
    return Duration(milliseconds: await _api.position(viewId));
  }

  @override
  Future<Duration> getDuration(int viewId) async {
    return Duration(milliseconds: await _api.duration(viewId));
  }

  @override
  Future<void> setVolume(int viewId, int volume) async {
    return _api.setVolume(viewId, volume);
  }

  @override
  Future<int?> getVolume(int viewId) async {
    return _api.getVolume(viewId);
  }

  @override
  Future<void> setPlaybackSpeed(int viewId, double speed) async {
    assert(speed > 0);

    return _api.setPlaybackSpeed(viewId, speed);
  }

  @override
  Future<double?> getPlaybackSpeed(int viewId) async {
    return _api.getPlaybackSpeed(viewId);
  }

  @override
  Future<int?> getSpuTracksCount(int viewId) async {
    return _api.getSpuTracksCount(viewId);
  }

  @override
  Future<Map<int, String>> getSpuTracks(int viewId) async {
    return _api.getSpuTracks(viewId);
  }

  @override
  Future<int?> getSpuTrack(int viewId) async {
    return _api.getSpuTrack(viewId);
  }

  @override
  Future<void> setSpuTrack(int viewId, int spuTrackNumber) async {
    return _api.setSpuTrack(viewId, spuTrackNumber);
  }

  @override
  Future<void> setSpuDelay(int viewId, int delay) async {
    return _api.setSpuDelay(viewId, delay);
  }

  @override
  Future<int?> getSpuDelay(int viewId) async {
    return _api.getSpuDelay(viewId);
  }

  @override
  Future<void> addSubtitleTrack(
    int viewId, {
    required String uri,
    required DataSourceType type,
    bool? isSelected,
  }) async {
    return _api.addSubtitleTrack(
      AddSubtitleMessage(
        playerId: viewId,
        uri: uri,
        type: type.index,
        isSelected: isSelected ?? false,
      ),
    );
  }

  @override
  Future<int?> getAudioTracksCount(int viewId) async {
    return _api.getAudioTracksCount(viewId);
  }

  @override
  Future<Map<int, String>> getAudioTracks(int viewId) async {
    return _api.getAudioTracks(viewId);
  }

  @override
  Future<int?> getAudioTrack(int viewId) async {
    return _api.getAudioTrack(viewId);
  }

  @override
  Future<void> setAudioTrack(int viewId, int audioTrackNumber) async {
    return _api.setAudioTrack(viewId, audioTrackNumber);
  }

  @override
  Future<void> setAudioDelay(int viewId, int delay) async {
    return _api.setAudioDelay(viewId, delay);
  }

  @override
  Future<int?> getAudioDelay(int viewId) async {
    return _api.getAudioDelay(viewId);
  }

  @override
  Future<void> addAudioTrack(
    int viewId, {
    required String uri,
    required DataSourceType type,
    bool? isSelected,
  }) async {
    return _api.addAudioTrack(
      AddAudioMessage(
        playerId: viewId,
        uri: uri,
        type: type.index,
        isSelected: isSelected ?? false,
      ),
    );
  }

  @override
  Future<int?> getVideoTracksCount(int viewId) async {
    return _api.getVideoTracksCount(viewId);
  }

  @override
  Future<Map<int, String>> getVideoTracks(int viewId) async {
    return _api.getVideoTracks(viewId);
  }

  @override
  Future<void> setVideoTrack(int viewId, int videoTrackNumber) async {
    return _api.setVideoTrack(viewId, videoTrackNumber);
  }

  @override
  Future<int?> getVideoTrack(int viewId) async {
    return _api.getVideoTrack(viewId);
  }

  @override
  Future<void> setVideoScale(int viewId, double scale) async {
    return _api.setVideoScale(viewId, scale);
  }

  @override
  Future<double?> getVideoScale(int viewId) async {
    return _api.getVideoScale(viewId);
  }

  @override
  Future<void> setVideoAspectRatio(int viewId, String aspect) async {
    return _api.setVideoAspectRatio(viewId, aspect);
  }

  @override
  Future<String?> getVideoAspectRatio(int viewId) async {
    return _api.getVideoAspectRatio(viewId);
  }

  String base64Encode(List<int> value) => base64.encode(value);
  Uint8List base64Decode(String source) => base64.decode(source);

  @override
  Future<Uint8List> takeSnapshot(int viewId) async {
    final base64String = await _api.takeSnapshot(viewId) ?? "";

    return base64Decode(base64.normalize(base64String));
  }

  @override
  Future<List<String>> getAvailableRendererServices(int viewId) async {
    return _api.getAvailableRendererServices(viewId);
  }

  @override
  Future<void> startRendererScanning(
    int viewId, {
    String? rendererService,
  }) async {
    return _api.startRendererScanning(viewId, rendererService ?? '');
  }

  @override
  Future<void> stopRendererScanning(int viewId) async {
    return _api.stopRendererScanning(viewId);
  }

  @override
  Future<Map<String, String>> getRendererDevices(int viewId) async {
    return _api.getRendererDevices(viewId);
  }

  @override
  Future<void> castToRenderer(int viewId, String rendererDevice) async {
    return _api.castToRenderer(viewId, rendererDevice);
  }

  @override
  Stream<VlcRendererEvent> rendererEventsFor(int viewId) {
    return _rendererEventChannelFor(viewId).receiveBroadcastStream().map((
      dynamic event,
    ) {
      final Map<Object?, Object?> map = event as Map<Object?, Object?>;
      //
      switch (map['event']) {
        case 'attached':
          return VlcRendererEvent(
            eventType: VlcRendererEventType.attached,
            rendererId: map['id'].toString(),
            rendererName: map['name'].toString(),
          );
        //
        case 'detached':
          return VlcRendererEvent(
            eventType: VlcRendererEventType.detached,
            rendererId: map['id'].toString(),
            rendererName: map['name'].toString(),
          );
        //
        default:
          return VlcRendererEvent(eventType: VlcRendererEventType.unknown);
      }
    });
  }

  @override
  Future<bool?> startRecording(int viewId, String saveDirectory) async {
    return _api.startRecording(viewId, saveDirectory);
  }

  @override
  Future<bool?> stopRecording(int viewId) async {
    return _api.stopRecording(viewId);
  }
}
