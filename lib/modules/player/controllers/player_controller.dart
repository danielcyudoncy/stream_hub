import 'dart:async';
import 'package:get/get.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/playback_state.dart';
import 'package:stream_hub/core/media/enums/playback_speed.dart';
import 'package:stream_hub/core/media/enums/player_quality.dart';
import 'package:stream_hub/core/media/enums/aspect_ratio_mode.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/media/player/player_adapter.dart';
import 'package:stream_hub/core/media/player/player_settings.dart';
import 'package:stream_hub/core/media/player/playable_media_session.dart';
import 'package:stream_hub/core/media/player/playback_controller.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/playable_stream.dart';

class PlayerController extends GetxController {
  final PlaybackController playbackController;
  final String? itemId;
  final String? streamUrl;

  PlayerController({
    this.itemId,
    this.streamUrl,
    PlayerAdapter? adapter,
    PlayerSettings? settings,
    LoggingService? logger,
  }) : playbackController = PlaybackController(
          adapter: adapter,
          settings: settings,
          logger: logger,
        );

  PlayableMediaSession? get session => playbackController.engine.currentSession;
  PlaybackState get state => playbackController.engine.currentState;
  Duration get position => playbackController.engine.positionRx.value;
  Duration get duration => playbackController.engine.durationRx.value;
  Duration get buffer => playbackController.engine.bufferRx.value;

  @override
  void onInit() {
    super.onInit();
    if (itemId != null && streamUrl != null) {
      _autoStart(itemId!, streamUrl!);
    }
    playbackController.addEventListener(_onPlaybackEvent);
  }

  @override
  void onClose() {
    playbackController.removeEventListener(_onPlaybackEvent);
    super.onClose();
  }

  Future<void> _autoStart(String itemId, String streamUrl) async {
    final mediaItem = MediaItem(
      id: itemId,
      providerId: 'unknown',
      providerType: MediaSourceType.m3u,
      mediaType: MediaType.channel,
      title: 'Live Stream',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final stream = PlayableStream(url: streamUrl);
    await playbackController.playMedia(mediaItem, stream);
  }

  Future<void> playMedia(
    MediaItem mediaItem,
    PlayableStream stream, {
    String? providerId,
    Duration? resumePosition,
  }) async {
    await playbackController.playMedia(
      mediaItem,
      stream,
      providerId: providerId,
      resumePosition: resumePosition,
    );
  }

  Future<void> play() => playbackController.play();
  Future<void> pause() => playbackController.pause();
  Future<void> resume() => playbackController.resume();
  Future<void> stop() => playbackController.stop();
  Future<void> seek(Duration position) => playbackController.seek(position);
  Future<void> replay() => playbackController.replay();
  Future<void> next() => playbackController.next();
  Future<void> previous() => playbackController.previous();
  Future<void> setSpeed(PlaybackSpeed speed) => playbackController.setSpeed(speed);
  Future<void> setAspectRatio(AspectRatioMode mode) => playbackController.setAspectRatio(mode);
  Future<void> setQuality(PlayerQuality quality) => playbackController.setQuality(quality);
  Future<void> setSubtitleTrack(String trackId) => playbackController.setSubtitleTrack(trackId);
  Future<void> setAudioTrack(String trackId) => playbackController.setAudioTrack(trackId);
  Future<void> setVolume(double volume) => playbackController.setVolume(volume);
  Future<void> setMuted(bool muted) => playbackController.setMuted(muted);

  void _onPlaybackEvent(dynamic event) {
    update(['player']);
  }
}
