import 'package:stream_hub/core/streaming/cache/session_cache.dart';
import 'package:stream_hub/core/streaming/cache/stream_cache.dart';
import 'package:stream_hub/core/streaming/models/playable_session.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';
import 'package:stream_hub/core/streaming/repositories/stream_cache_repository.dart';

class StreamCacheRepositoryImpl implements StreamCacheRepository {
  final StreamCache streamCache;
  final SessionCache sessionCache;

  StreamCacheRepositoryImpl(this.streamCache, this.sessionCache);

  @override
  PlayableSession? getCachedSession(String providerId, String mediaItemId) {
    return streamCache.getSession('$providerId:$mediaItemId');
  }

  @override
  Future<ProviderSession?> getProviderSession(String providerId) {
    return sessionCache.getProviderSession(providerId);
  }

  @override
  Future<void> saveProviderSession(ProviderSession session) {
    return sessionCache.saveProviderSession(session);
  }

  @override
  Future<void> deleteProviderSession(String providerId) {
    return sessionCache.deleteProviderSession(providerId);
  }

  @override
  Future<void> clearStreamCache() async {
    streamCache.clear();
  }

  @override
  Future<void> clearAll() async {
    streamCache.clear();
    await sessionCache.clear();
  }
}
