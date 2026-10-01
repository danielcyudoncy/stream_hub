import 'dart:io';

import 'package:get/get.dart';
import '../../../core/logging/logging_service.dart';
import '../../../data/models/cache_info.dart';
import '../../../data/repositories/settings_repository.dart';

class CacheService extends GetxService {
  final SettingsRepository _settingsRepository;
  final LoggingService _logger = Get.find<LoggingService>();

  CacheService(this._settingsRepository);

  Future<int> _calculateDirectorySize(Directory dir) async {
    int total = 0;
    try {
      if (!await dir.exists()) return 0;
      await for (final entity in dir
          .list(recursive: false, followLinks: false)
          .handleError((_) {})) {
        if (entity is File) {
          try {
            final stat = await entity.stat();
            total += stat.size;
          } catch (_) {}
        } else if (entity is Directory) {
          total += await _calculateDirectorySize(entity);
        }
      }
    } catch (_) {}
    return total;
  }

  Future<CacheInfo> calculateCacheSize() async {
    try {
      int imageCacheSize = 0;
      int tempFilesSize = 0;
      int metadataCacheSize = 0;

      try {
        final knownAppTempDirs = [
          Directory('${Directory.systemTemp.path}/stream_hub_downloads'),
          Directory('${Directory.systemTemp.path}/stream_hub'),
          Directory('${Directory.systemTemp.path}/m3u_playlists'),
        ];

        for (final dir in knownAppTempDirs) {
          tempFilesSize += await _calculateDirectorySize(dir);
        }

        final tempDir = Directory.systemTemp;
        if (await tempDir.exists()) {
          await for (final entity in tempDir
              .list(recursive: false, followLinks: false)
              .handleError((_) {})) {
            final name = entity.uri.pathSegments.isNotEmpty
                ? entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => '')
                : '';
            if (name.startsWith('stream_hub') || name.startsWith('streamhub')) {
              if (entity is File) {
                try {
                  final stat = await entity.stat();
                  tempFilesSize += stat.size;
                } catch (_) {}
              } else if (entity is Directory && !knownAppTempDirs.any((d) => d.path == entity.path)) {
                tempFilesSize += await _calculateDirectorySize(entity);
              }
            }
          }
        }
      } catch (e) {
        _logger.warning('Failed to calculate temp directory size', tag: 'CacheService', error: e);
      }

      try {
        final appDir = Directory.current;
        final cacheDir = Directory('${appDir.path}/.dart_tool');
        metadataCacheSize = await _calculateDirectorySize(cacheDir);
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
        final knownAppTempDirs = [
          Directory('${Directory.systemTemp.path}/stream_hub_downloads'),
          Directory('${Directory.systemTemp.path}/stream_hub'),
          Directory('${Directory.systemTemp.path}/m3u_playlists'),
        ];

        for (final dir in knownAppTempDirs) {
          try {
            if (await dir.exists()) {
              await dir.delete(recursive: true);
            }
          } catch (e) {
            errors.add(dir.path);
          }
        }

        final tempDir = Directory.systemTemp;
        if (await tempDir.exists()) {
          await for (final entity in tempDir
              .list(recursive: false, followLinks: false)
              .handleError((_) {})) {
            final name = entity.uri.pathSegments.isNotEmpty
                ? entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => '')
                : '';
            if (name.startsWith('stream_hub') || name.startsWith('streamhub')) {
              try {
                if (entity is File) await entity.delete();
                if (entity is Directory) await entity.delete(recursive: true);
              } catch (e) {
                errors.add(entity.path);
              }
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
          await for (final entity in cacheDir
              .list(recursive: false, followLinks: false)
              .handleError((_) {})) {
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