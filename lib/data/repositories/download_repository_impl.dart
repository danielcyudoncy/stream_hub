import 'dart:async';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:stream_hub/core/constants/app_constants.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/repositories/download_repository.dart';
import 'package:stream_hub/data/models/download_item.dart';
import 'package:stream_hub/data/services/database_service.dart';

/// Hive-backed implementation of [DownloadRepository].
class DownloadRepositoryImpl implements DownloadRepository {
  final DatabaseService? _databaseService;
  final LoggingService? _logger;
  final StreamController<List<DownloadItem>> _streamController =
      StreamController<List<DownloadItem>>.broadcast();

  DownloadRepositoryImpl({
    DatabaseService? databaseService,
    LoggingService? logger,
  })  : _databaseService = databaseService,
        _logger = logger;

  Box get _box {
    if (_databaseService != null) {
      return _databaseService.downloadsBox;
    }
    if (Get.isRegistered<DatabaseService>()) {
      return Get.find<DatabaseService>().downloadsBox;
    }
    if (Hive.isBoxOpen(AppConstants.boxDownloads)) {
      return Hive.box(AppConstants.boxDownloads);
    }
    throw StateError('Downloads box is not open and DatabaseService is not registered.');
  }

  void _log(String message, {Object? error}) {
    if (_logger != null) {
      if (error != null) {
        _logger.error(message, tag: 'DownloadRepository', error: error);
      } else {
        _logger.info(message, tag: 'DownloadRepository');
      }
    } else if (Get.isRegistered<LoggingService>()) {
      final l = Get.find<LoggingService>();
      if (error != null) {
        l.error(message, tag: 'DownloadRepository', error: error);
      } else {
        l.info(message, tag: 'DownloadRepository');
      }
    }
  }

  @override
  Future<List<DownloadItem>> getAllDownloads() async {
    try {
      final box = _box;
      final raw = box.values.toList();
      final items = <DownloadItem>[];
      for (final val in raw) {
        if (val is Map) {
          try {
            items.add(DownloadItem.fromMap(val));
          } catch (e) {
            _log('Failed to parse download record', error: e);
          }
        }
      }
      // Sort newest first
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    } catch (e) {
      _log('Failed to fetch all downloads', error: e);
      return [];
    }
  }

  @override
  Future<DownloadItem?> getDownload(String id) async {
    try {
      final box = _box;
      final raw = box.get(id);
      if (raw is Map) {
        return DownloadItem.fromMap(raw);
      }
      return null;
    } catch (e) {
      _log('Failed to get download by id: $id', error: e);
      return null;
    }
  }

  @override
  Future<void> saveDownload(DownloadItem item) async {
    try {
      final box = _box;
      await box.put(item.id, item.toMap());
      _notify();
    } catch (e) {
      _log('Failed to save download: ${item.id}', error: e);
      rethrow;
    }
  }

  @override
  Future<void> deleteDownload(String id) async {
    try {
      final box = _box;
      await box.delete(id);
      _notify();
    } catch (e) {
      _log('Failed to delete download: $id', error: e);
      rethrow;
    }
  }

  @override
  Future<void> clearAll() async {
    try {
      final box = _box;
      await box.clear();
      _notify();
    } catch (e) {
      _log('Failed to clear downloads', error: e);
      rethrow;
    }
  }

  @override
  Stream<List<DownloadItem>> watchDownloads() {
    // Emit current list immediately
    getAllDownloads().then((items) {
      if (!_streamController.isClosed) {
        _streamController.add(items);
      }
    });
    return _streamController.stream;
  }

  void _notify() {
    if (_streamController.hasListener && !_streamController.isClosed) {
      getAllDownloads().then((items) {
        if (!_streamController.isClosed) {
          _streamController.add(items);
        }
      });
    }
  }

  void dispose() {
    _streamController.close();
  }
}
