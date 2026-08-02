import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/streaming/models/playable_session.dart';
import 'package:stream_hub/core/streaming/models/prepared_download.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';

/// Exposes stream engine operations to controllers and use cases.
///
/// Controllers must never talk to the [StreamEngine] directly; they use this
/// repository boundary so playback preparation stays decoupled from the UI.
abstract class StreamRepository {
  /// Resolves a media item into a validated playable session.
  Future<PlayableSession> resolvePlayback({
    required String mediaItemId,
    required MediaSourceType providerType,
    required Map<String, dynamic> itemMetadata,
    String? providerId,
    String? fallbackUrl,
    bool useCache = true,
    bool validate = true,
  });

  /// Resolves a raw source URL using an existing provider session.
  Future<PlayableSession> resolveStream({
    required String mediaItemId,
    required String url,
    required ProviderSession providerSession,
    Map<String, dynamic> itemMetadata = const {},
  });

  /// Prepares an authenticated, downloadable stream for a media item.
  Future<PreparedDownload> prepareDownload({
    required String mediaItemId,
    required MediaSourceType providerType,
    required Map<String, dynamic> itemMetadata,
    String? providerId,
    String? fallbackUrl,
    bool validate = true,
  });

  /// Validates an existing playable session.
  Future<bool> validate(PlayableSession session);

  /// Selects a working stream (primary or backup) for a session.
  Future<PlayableSession> selectWorking(PlayableSession session);

  /// Starts background maintenance tasks (session refresh, cache eviction).
  Future<void> startBackgroundTasks();

  Future<void> stopBackgroundTasks();
}
