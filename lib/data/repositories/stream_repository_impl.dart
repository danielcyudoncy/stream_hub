import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/streaming/models/playable_session.dart';
import 'package:stream_hub/core/streaming/models/prepared_download.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';
import 'package:stream_hub/core/streaming/repositories/stream_repository.dart';
import 'package:stream_hub/core/streaming/stream_engine.dart';

class StreamRepositoryImpl implements StreamRepository {
  final StreamEngine engine;

  StreamRepositoryImpl(this.engine);

  @override
  Future<PlayableSession> resolvePlayback({
    required String mediaItemId,
    required MediaSourceType providerType,
    required Map<String, dynamic> itemMetadata,
    String? providerId,
    String? fallbackUrl,
    bool useCache = true,
    bool validate = true,
  }) {
    return engine.resolvePlayback(
      mediaItemId: mediaItemId,
      providerType: providerType,
      itemMetadata: itemMetadata,
      providerId: providerId,
      fallbackUrl: fallbackUrl,
      useCache: useCache,
      validate: validate,
    );
  }

  @override
  Future<PlayableSession> resolveStream({
    required String mediaItemId,
    required String url,
    required ProviderSession providerSession,
    Map<String, dynamic> itemMetadata = const {},
  }) {
    return engine.resolveStream(
      mediaItemId: mediaItemId,
      url: url,
      providerSession: providerSession,
      itemMetadata: itemMetadata,
    );
  }

  @override
  Future<PreparedDownload> prepareDownload({
    required String mediaItemId,
    required MediaSourceType providerType,
    required Map<String, dynamic> itemMetadata,
    String? providerId,
    String? fallbackUrl,
    bool validate = true,
  }) {
    return engine.prepareDownload(
      mediaItemId: mediaItemId,
      providerType: providerType,
      itemMetadata: itemMetadata,
      providerId: providerId,
      fallbackUrl: fallbackUrl,
      validate: validate,
    );
  }

  @override
  Future<bool> validate(PlayableSession session) {
    return engine.validateStream(session);
  }

  @override
  Future<PlayableSession> selectWorking(PlayableSession session) {
    return engine.selectWorkingStream(session);
  }

  @override
  Future<void> startBackgroundTasks() {
    return engine.startBackgroundTasks();
  }

  @override
  Future<void> stopBackgroundTasks() {
    return engine.stopBackgroundTasks();
  }
}
