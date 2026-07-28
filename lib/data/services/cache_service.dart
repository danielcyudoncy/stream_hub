import 'dart:io';

import 'package:get/get.dart';
import '../../../core/logging/logging_service.dart';
import '../../../data/models/cache_info.dart';
import '../../../data/repositories/settings_repository.dart';

class CacheService extends GetxService {
  final SettingsRepository _settingsRepository;
  final LoggingService _logger = Get.find<LoggingService>();

  CacheService(this._settingsRepository);

  Future<CacheInfo> calculateCacheSize() async {
    try {
      int imageCacheSize = 0;
      int tempFilesSize = 0;
      int metadataCacheSize = 0;

      try {
        final tempDir = Directory.systemTemp;
        if (await tempDir.exists()) {
          await for (final entity in tempDir.list(recursive: true, followLinks: false)) {
            if (entity is File) {
              try {
                final stat = await entity.stat();
                tempFilesSize += stat.size;
              } catch (_) {}
            }
          }
        }
      } catch (e) {
        _logger.warning('Failed to calculate temp directory size', tag: 'CacheService', error: e);
      }

      try {
        final appDir = Directory.current;
        final cacheDir = Directory('${appDir.path}/.dart_tool');
        if (await cacheDir.exists()) {
          await for (final entity in cacheDir.list(recursive: true, followLinks: false)) {
            if (entity is File) {
              try {
                final stat = await entity.stat();
                metadataCacheSize += stat.size;
              } catch (_) {}
            }
          }
        }
      } catch (e) {
        _logger.warning('Failed to calculate metadata cache size', tag: 'CacheService', error: e);
      }

      imageCacheSize = _estimateImageCacheSize();

      final totalSize = imageCacheSize + tempFilesSize + metadataCacheSize;

      return CacheInfo(
        id: 'global',
        totalSize: totalSize,
        imageCacheSize: imageCacheSize,
        temporaryFilesSize: tempFilesSize,
        metadataCacheSize: metadataCacheSize,
        lastCalculated: DateTime.now(),
      );
    } catch (e) {
      _logger.error('Failed to calculate cache size', tag: 'CacheService', error: e);
      return CacheInfo(
        id: 'global',
        totalSize: 0,
        imageCacheSize: 0,
        temporaryFilesSize: 0,
        metadataCacheSize: 0,
        lastCalculated: DateTime.now(),
      );
    }
  }

  Future<void> clearCache() async {
    try {
      final errors = <String>[];

      try {
        final tempDir = Directory.systemTemp;
        if (await tempDir.exists()) {
          await for (final entity in tempDir.list(recursive: true, followLinks: false)) {
            try {
              if (entity is File) await entity.delete();
              if (entity is Directory) await entity.delete(recursive: true);
            } catch (e) {
              errors.add(entity.path);
            }
          }
        }
      } catch (e) {
        _logger.warning('Failed to clear temp files', tag: 'CacheService', error: e);
      }

      try {
        final appDir = Directory.current;
        final cacheDir = Directory('${appDir.path}/.dart_tool');
        if (await cacheDir.exists()) {
          await for (final entity in cacheDir.list(recursive: true, followLinks: false)) {
            try {
              if (entity is File) await entity.delete();
              if (entity is Directory) await entity.delete(recursive: true);
            } catch (e) {
              errors.add(entity.path);
            }
          }
        }
      } catch (e) {
        _logger.warning('Failed to clear metadata cache', tag: 'CacheService', error: e);
      }

      await _settingsRepository.clearCacheTimestamp();

      if (errors.isNotEmpty) {
        _logger.warning(
          'Cache cleared with ${errors.length} errors',
          tag: 'CacheService',
        );
      }
    } catch (e) {
      _logger.error('Failed to clear cache', tag: 'CacheService', error: e);
      rethrow;
    }
  }

  Future<void> clearImageCache() async {
    try {
      final imageCacheDir = Directory('${Directory.current.path}/cache/images');
      if (await imageCacheDir.exists()) {
        await imageCacheDir.delete(recursive: true);
      }
    } catch (e) {
      _logger.warning('Failed to clear image cache', tag: 'CacheService', error: e);
    }
  }

  int _estimateImageCacheSize() {
    try {
      final imageCacheDir = Directory('${Directory.current.path}/cache/images');
      if (!imageCacheDir.existsSync()) return 0;

      int total = 0;
      for (final entity in imageCacheDir.listSync(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            total += entity.lengthSync();
          } catch (_) {}
        }
      }
      return total;
    } catch (e) {
      return 0;
    }
  }
}