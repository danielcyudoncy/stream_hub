import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/models/xmltv_models.dart';

class XMLTVCacheService {
  final LoggingService _logger;
  final Map<String, XMLTVGuideCache> _cache = {};
  final Map<String, String> _hashes = {};

  XMLTVCacheService(this._logger);

  Future<void> cacheGuide(XMLTVGuideCache cache) async {
    _cache[cache.sourceId] = cache;
    _hashes[cache.sourceId] = cache.contentHash;
    _logger.info(
      'Cached XMLTV guide for source ${cache.sourceId} (${cache.guide.programs.length} programs)',
      tag: 'XMLTVCacheService',
    );
  }

  Future<XMLTVGuideCache?> getCachedGuide(String sourceId) async {
    return _cache[sourceId];
  }

  Future<void> removeCachedGuide(String sourceId) async {
    _cache.remove(sourceId);
    _hashes.remove(sourceId);
  }

  Future<void> clearAll() async {
    _cache.clear();
    _hashes.clear();
  }

  String computeContentHash(String content) {
    var hash = 0;
    for (int i = 0; i < content.length; i++) {
      hash = ((hash << 5) - hash + content.codeUnitAt(i)) & 0xFFFFFFFF;
    }
    return hash.toUnsigned(32).toRadixString(16).padLeft(8, '0');
  }

  bool hasContentChanged(String sourceId, String content) {
    final newHash = computeContentHash(content);
    return _hashes[sourceId] != newHash;
  }

  List<XMLTVGuideCache> getAllCachedGuides() {
    return _cache.values.toList();
  }

  int get cachedGuideCount => _cache.length;
}