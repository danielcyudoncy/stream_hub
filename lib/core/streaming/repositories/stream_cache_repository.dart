import 'package:stream_hub/core/streaming/models/playable_session.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';

/// Access to the in-memory stream cache and the persistent provider session
/// cache.
abstract class StreamCacheRepository {
  PlayableSession? getCachedSession(String providerId, String mediaItemId);

  Future<ProviderSession?> getProviderSession(String providerId);

  Future<void> saveProviderSession(ProviderSession session);

  Future<void> deleteProviderSession(String providerId);

  Future<void> clearStreamCache();

  Future<void> clearAll();
}
