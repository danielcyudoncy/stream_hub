import 'dart:convert';

import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:stream_hub/core/constants/app_constants.dart';
import 'package:stream_hub/core/errors/exceptions.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/models/m3u_models.dart';

class PlaylistCacheService extends GetxService {
  final LoggingService _logger;

  late Box _cacheBox;

  PlaylistCacheService(this._logger);

  Future<PlaylistCacheService> init() async {
    try {
      _cacheBox = await Hive.openBox(AppConstants.boxCache);
      _logger.info('PlaylistCacheService initialized', tag: 'PlaylistCacheService');
    } catch (e) {
      _logger.error(
        'Failed to initialize PlaylistCacheService',
        tag: 'PlaylistCacheService',
        error: e,
      );
      rethrow;
    }
    return this;
  }

  Future<void> cachePlaylist(M3UPlaylistCache cache) async {
    try {
      await _cacheBox.put(cache.sourceId, {
        'sourceId': cache.sourceId,
        'rawPlaylist': cache.rawPlaylist,
        'channels': _serializeChannels(cache.channels),
        'statistics': _serializeStatistics(cache.statistics),
        'validation': _serializeValidation(cache.validation),
        'cachedAt': cache.cachedAt.millisecondsSinceEpoch,
        'expiresAt': cache.expiresAt.millisecondsSinceEpoch,
        'etag': cache.etag,
        'lastModified': cache.lastModified,
        'contentHash': cache.contentHash,
      });
    } catch (e) {
      _logger.error(
        'Failed to cache playlist',
        tag: 'PlaylistCacheService',
        error: e,
      );
      throw DatabaseException(
        message: 'Failed to cache playlist',
        originalError: e,
      );
    }
  }

  Future<M3UPlaylistCache?> getCachedPlaylist(String sourceId) async {
    try {
      final raw = _cacheBox.get(sourceId);
      if (raw == null) return null;

      final map = Map<dynamic, dynamic>.from(raw as Map);
      final cachedAt = DateTime.fromMillisecondsSinceEpoch(map['cachedAt'] as int);
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(map['expiresAt'] as int);

      if (DateTime.now().isAfter(expiresAt)) {
        _logger.info(
          'Cached playlist expired for $sourceId',
          tag: 'PlaylistCacheService',
        );
        await removeCachedPlaylist(sourceId);
        return null;
      }

      return M3UPlaylistCache(
        sourceId: map['sourceId'] as String,
        rawPlaylist: map['rawPlaylist'] as String,
        channels: _deserializeChannels(map['channels'] as List? ?? []),
        statistics: _deserializeStatistics(map['statistics'] as Map? ?? {}),
        validation: _deserializeValidation(map['validation'] as Map? ?? {}),
        cachedAt: cachedAt,
        expiresAt: expiresAt,
        etag: map['etag'] as String?,
        lastModified: map['lastModified'] as String?,
        contentHash: map['contentHash'] as String,
      );
    } catch (e) {
      _logger.warning(
        'Failed to read cached playlist',
        tag: 'PlaylistCacheService',
        error: e,
      );
      return null;
    }
  }

  Future<void> removeCachedPlaylist(String sourceId) async {
    try {
      await _cacheBox.delete(sourceId);
    } catch (e) {
      _logger.warning(
        'Failed to remove cached playlist',
        tag: 'PlaylistCacheService',
        error: e,
      );
    }
  }

  Future<void> clearAll() async {
    try {
      await _cacheBox.clear();
    } catch (e) {
      _logger.warning(
        'Failed to clear playlist cache',
        tag: 'PlaylistCacheService',
        error: e,
      );
    }
  }

  Future<int> get cacheSize async {
    try {
      return _cacheBox.length;
    } catch (_) {
      return 0;
    }
  }

  String computeContentHash(String content) {
    final bytes = utf8.encode(content);
    var hash = 0;
    for (final byte in bytes) {
      hash = ((hash << 5) - hash) + byte;
      hash = hash & hash;
    }
    return hash.toRadixString(16);
  }

  List<Map<String, dynamic>> _serializeChannels(List<M3UChannel> channels) {
    return channels
        .map(
          (c) => {
            'id': c.id,
            'title': c.title,
            'streamUrl': c.streamUrl,
            'logo': c.logo,
            'group': c.group,
            'tvgId': c.tvgId,
            'tvgName': c.tvgName,
            'isRadio': c.isRadio,
            'language': c.language,
            'country': c.country,
            'catchup': c.catchup,
            'attributes': c.attributes,
            'warnings': c.warnings,
          },
        )
        .toList();
  }

  List<M3UChannel> _deserializeChannels(List<dynamic> raw) {
    return raw
        .map(
          (c) => M3UChannel(
            id: c['id'] as String,
            title: c['title'] as String,
            streamUrl: c['streamUrl'] as String?,
            logo: c['logo'] as String?,
            group: c['group'] as String?,
            tvgId: c['tvgId'] as String?,
            tvgName: c['tvgName'] as String?,
            isRadio: c['isRadio'] as bool? ?? false,
            language: c['language'] as String?,
            country: c['country'] as String?,
            catchup: Map<String, String>.from(c['catchup'] as Map? ?? {}),
            attributes: Map<String, String>.from(c['attributes'] as Map? ?? {}),
            warnings: List<String>.from(c['warnings'] as List? ?? []),
          ),
        )
        .toList();
  }

  Map<String, dynamic> _serializeStatistics(M3UStatistics stats) {
    return {
      'totalItems': stats.totalItems,
      'channels': stats.channels,
      'radioCount': stats.radioCount,
      'categories': stats.categories,
      'languages': stats.languages,
      'countries': stats.countries,
      'invalidEntries': stats.invalidEntries,
      'duplicates': stats.duplicates,
      'syncDurationMs': stats.syncDuration.inMilliseconds,
      'lastSync': stats.lastSync.millisecondsSinceEpoch,
    };
  }

  M3UStatistics _deserializeStatistics(Map<dynamic, dynamic> raw) {
    return M3UStatistics(
      totalItems: raw['totalItems'] as int? ?? 0,
      channels: raw['channels'] as int? ?? 0,
      radioCount: raw['radioCount'] as int? ?? 0,
      categories: raw['categories'] as int? ?? 0,
      languages: raw['languages'] as int? ?? 0,
      countries: raw['countries'] as int? ?? 0,
      invalidEntries: raw['invalidEntries'] as int? ?? 0,
      duplicates: raw['duplicates'] as int? ?? 0,
      syncDuration: Duration(milliseconds: raw['syncDurationMs'] as int? ?? 0),
      lastSync: DateTime.fromMillisecondsSinceEpoch(raw['lastSync'] as int? ?? DateTime.now().millisecondsSinceEpoch),
    );
  }

  Map<String, dynamic> _serializeValidation(M3UValidationResult validation) {
    return {
      'isValid': validation.isValid,
      'hasValidHeader': validation.hasValidHeader,
      'encoding': validation.encoding,
      'errors': validation.errors,
      'warnings': validation.warnings,
      'duplicateCount': validation.duplicateCount,
      'missingUrlCount': validation.missingUrlCount,
      'malformedEntryCount': validation.malformedEntryCount,
    };
  }

  M3UValidationResult _deserializeValidation(Map<dynamic, dynamic> raw) {
    return M3UValidationResult(
      isValid: raw['isValid'] as bool? ?? true,
      hasValidHeader: raw['hasValidHeader'] as bool? ?? false,
      encoding: raw['encoding'] as String?,
      errors: List<String>.from(raw['errors'] as List? ?? []),
      warnings: List<String>.from(raw['warnings'] as List? ?? []),
      duplicateCount: raw['duplicateCount'] as int? ?? 0,
      missingUrlCount: raw['missingUrlCount'] as int? ?? 0,
      malformedEntryCount: raw['malformedEntryCount'] as int? ?? 0,
    );
  }
}
