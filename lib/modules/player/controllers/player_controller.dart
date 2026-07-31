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
import 'package:stream_hub/core/media/stream_resolver.dart';
import 'package:stream_hub/core/media/stream_resolvers/m3u_stream_resolver.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/playable_stream.dart';
import 'package:stream_hub/data/repositories/history_repository.dart';
import 'package:stream_hub/data/repositories/favorite_repository.dart';

class PlayerController extends GetxController {
  final PlaybackController playbackController;
  final StreamResolver streamResolver;
  final HistoryRepository? historyRepository;
  final FavoriteRepository? favoriteRepository;

  final String? itemId;
  final String? streamUrl;

  final RxList<MediaItem> channelList = <MediaItem>[].obs;
  int _currentChannelIndex = -1;

  PlayerController({
    this.itemId,
    this.streamUrl,
    PlayerAdapter? adapter,
    PlayerSettings? settings,
    LoggingService? logger,
    StreamResolver? streamResolver,
    this.historyRepository,
    this.favoriteRepository,
  })  : playbackController = PlaybackController(
          adapter: adapter,
          settings: settings,
          logger: logger,
        ),
        streamResolver = streamResolver ?? M3UStreamResolver();

  PlayableMediaSession? get session => playbackController.engine.currentSession;
  PlaybackState get state => playbackController.engine.currentState;
  Duration get position => playbackController.engine.positionRx.value;
  Duration get duration => playbackController.engine.durationRx.value;
  Duration get buffer => playbackController.engine.bufferRx.value;
  MediaItem? get currentItem => session?.mediaItem;
  bool get canSwitchNext => _currentChannelIndex < channelList.length - 1;
  bool get canSwitchPrevious => _currentChannelIndex > 0;

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
    playbackController.stop();
    super.onClose();
  }

  Future<void> _autoStart(String id, String url) async {
    final mediaItem = MediaItem(
      id: id,
      providerId: 'unknown',
      providerType: MediaSourceType.m3u,
      mediaType: MediaType.channel,
      title: 'Live Stream',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final stream = PlayableStream(url: url);
    await playMedia(mediaItem, stream);
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
    _recordPlayback(mediaItem);
  }

  Future<void> playMediaItem(MediaItem item) async {
    final stream = await streamResolver.resolve(item);
    final isValid = await streamResolver.validate(stream);
    if (!isValid) {
      throw Exception('Invalid stream for ${item.title}');
    }
    await playMedia(item, stream);
  }

  void setChannelList(List<MediaItem> channels, {String? currentId}) {
    channelList.assignAll(channels);
    _currentChannelIndex =
        currentId != null ? channels.indexWhere((c) => c.id == currentId) : -1;
  }

  Future<void> switchToChannel(int index) async {
    if (index < 0 || index >= channelList.length) return;
    _currentChannelIndex = index;
    final item = channelList[index];
    await playMediaItem(item);
  }

  Future<void> switchToNextChannel() async {
    if (canSwitchNext) {
      await switchToChannel(_currentChannelIndex + 1);
    }
  }

  Future<void> switchToPreviousChannel() async {
    if (canSwitchPrevious) {
      await switchToChannel(_currentChannelIndex - 1);
    }
  }

  Future<void> play() => playbackController.play();
  Future<void> pause() => playbackController.pause();
  Future<void> resume() => playbackController.resume();
  Future<void> stop() => playbackController.stop();
  Future<void> seek(Duration position) => playbackController.seek(position);
  Future<void> replay() => playbackController.replay();
  Future<void> next() => switchToNextChannel();
  Future<void> previous() => switchToPreviousChannel();
  Future<void> retry() => playbackController.retry();

  Future<void> setSpeed(PlaybackSpeed speed) =>
      playbackController.setSpeed(speed);
  Future<void> setAspectRatio(AspectRatioMode mode) =>
      playbackController.setAspectRatio(mode);
  Future<void> setQuality(PlayerQuality quality) =>
      playbackController.setQuality(quality);
  Future<void> setSubtitleTrack(String trackId) =>
      playbackController.setSubtitleTrack(trackId);
  Future<void> setAudioTrack(String trackId) =>
      playbackController.setAudioTrack(trackId);
  Future<void> setVolume(double volume) =>
      playbackController.setVolume(volume);
  Future<void> setMuted(bool muted) => playbackController.setMuted(muted);

  Future<void> toggleFavorite() async {
    final item = currentItem;
    if (item == null || favoriteRepository == null) return;
    if (item.favorite) {
      await favoriteRepository!.remove(item.id);
    } else {
      await favoriteRepository!.add(item.copyWith(favorite: true));
    }
  }

  void _recordPlayback(MediaItem item) {
    historyRepository?.add(item);
  }

  void _onPlaybackEvent(dynamic event) {
    update(['player']);
  }
}
