import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/logging/logging_service.dart';
import '../models/subscription/subscription_model.dart';
import 'database_service.dart';

/// Local persistence service for subscriptions backed by Hive.
///
/// Ensures offline-first capability: entitlement checks never block UI on network
/// latency and function seamlessly when device is offline.
class SubscriptionLocalService extends GetxService {
  final DatabaseService _databaseService;
  final LoggingService _logger;

  SubscriptionLocalService({
    DatabaseService? databaseService,
    LoggingService? logger,
  })  : _databaseService = databaseService ?? Get.find<DatabaseService>(),
        _logger = logger ?? (Get.isRegistered<LoggingService>() ? Get.find<LoggingService>() : LoggingService());

  Box get _box => _databaseService.subscriptionBox;

  static const String _kCurrentSubscriptionKey = 'current_active_subscription';

  /// Retrieves the cached subscription for a user.
  Future<SubscriptionModel?> getSubscription([String? userId]) async {
    try {
      final key = userId != null && userId.isNotEmpty ? 'sub_$userId' : _kCurrentSubscriptionKey;
      final raw = _box.get(key);
      if (raw == null) return null;

      if (raw is Map) {
        final map = Map<String, dynamic>.from(raw);
        return SubscriptionModel.fromJson(map);
      } else if (raw is String) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        return SubscriptionModel.fromJson(map);
      }
      return null;
    } catch (e) {
      _logger.error('Failed to read subscription from local Hive cache', tag: 'SubscriptionLocalService', error: e);
      return null;
    }
  }

  /// Persists the active subscription locally.
  Future<void> saveSubscription(SubscriptionModel subscription) async {
    try {
      final json = subscription.toJson();
      if (subscription.userId.isNotEmpty) {
        await _box.put('sub_${subscription.userId}', json);
      }
      // Also write to default current slot for instant access
      await _box.put(_kCurrentSubscriptionKey, json);
      _logger.info(
        'Subscription persisted locally: ${subscription.planName} (${subscription.status.name})',
        tag: 'SubscriptionLocalService',
      );
    } catch (e) {
      _logger.error('Failed to save subscription locally', tag: 'SubscriptionLocalService', error: e);
    }
  }

  /// Clears subscription state upon user logout.
  Future<void> clearSubscription([String? userId]) async {
    try {
      if (userId != null && userId.isNotEmpty) {
        await _box.delete('sub_$userId');
      }
      await _box.delete(_kCurrentSubscriptionKey);
      _logger.info('Subscription cleared from local storage', tag: 'SubscriptionLocalService');
    } catch (e) {
      _logger.error('Failed to clear subscription from local storage', tag: 'SubscriptionLocalService', error: e);
    }
  }
}
