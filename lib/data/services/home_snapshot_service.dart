import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/models/home_snapshot.dart';

class HomeSnapshotService {
  static const String _boxName = 'home_snapshot';
  static const String _snapshotKey = 'home_data';
  static const Duration defaultMaxAge = Duration(hours: 1);

  final LoggingService _logger;
  Box<String>? _box;

  HomeSnapshotService({LoggingService? logger})
      : _logger = logger ?? LoggingService();

  Future<void> init() async {
    try {
      _box = await Hive.openBox<String>(_boxName);
      _logger.info('HomeSnapshot box opened', tag: 'HomeSnapshot');
    } catch (e) {
      _logger.warning(
        'Failed to open HomeSnapshot box, attempting recovery',
        tag: 'HomeSnapshot',
        error: e,
      );
      try {
        await Hive.deleteBoxFromDisk(_boxName);
        _box = await Hive.openBox<String>(_boxName);
      } catch (_) {}
    }
  }

  Future<HomeSnapshot?> load() async {
    try {
      final box = _box;
      if (box == null || !box.isOpen) {
        await init();
      }
      final raw = _box?.get(_snapshotKey);
      if (raw == null || raw.isEmpty) {
        _logger.info('[HOME] Persistent cache miss', tag: 'HomeSnapshot');
        return null;
      }
      final decoded = await compute(jsonDecode, raw);
      if (decoded is! Map) {
        _logger.warning('[HOME] Decoded snapshot is not a map', tag: 'HomeSnapshot');
        return null;
      }
      final json = Map<String, dynamic>.from(decoded);
      final snapshot = HomeSnapshot.fromJson(json);
      _logger.info('[HOME] Persistent cache hit', tag: 'HomeSnapshot');
      return snapshot;
    } catch (e) {
      _logger.warning(
        'Failed to load HomeSnapshot',
        tag: 'HomeSnapshot',
        error: e,
      );
      return null;
    }
  }

  Future<void> save(HomeSnapshot snapshot) async {
    try {
      if (snapshot.isEmpty) {
        _logger.info(
          '[HOME] Aborting snapshot save: snapshot is empty to prevent wiping cache',
          tag: 'HomeSnapshot',
        );
        return;
      }
      final box = _box;
      if (box == null || !box.isOpen) {
        await init();
      }
      final jsonMap = snapshot.toJson();
      final json = await compute(jsonEncode, jsonMap);
      await _box?.put(_snapshotKey, json);
      _logger.info('[HOME] Snapshot persisted', tag: 'HomeSnapshot');
    } catch (e) {
      _logger.warning(
        'Failed to save HomeSnapshot',
        tag: 'HomeSnapshot',
        error: e,
      );
    }
  }

  Future<void> clear() async {
    try {
      await _box?.delete(_snapshotKey);
      _logger.info('HomeSnapshot cleared', tag: 'HomeSnapshot');
    } catch (_) {}
  }
}
