import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';

/// Converts a provider media item (and provider configuration) into a
/// [ProviderSession] — the provider adapter step of the pipeline.
///
/// Every provider (M3U, Xtream, Stalker, Plex, Jellyfin, Emby, ...) plugs into
/// the Stream Engine through a [ProviderSessionFactory]. No player or download
/// engine ever sees these provider-specific details.
abstract class ProviderSessionFactory {
  MediaSourceType get providerType;

  Future<ProviderSession> createSession({
    required String mediaItemId,
    required Map<String, dynamic> itemMetadata,
    Map<String, dynamic>? providerConfig,
    ProviderSession? existing,
  });
}
