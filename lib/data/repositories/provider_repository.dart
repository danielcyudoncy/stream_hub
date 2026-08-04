import 'dart:async';

import 'package:get/get.dart';
import 'package:stream_hub/core/errors/exceptions.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/services/database_service.dart';
import 'package:stream_hub/modules/provider_manager/models/provider_enums.dart';
import 'package:stream_hub/modules/provider_manager/models/provider_model.dart';

class ProviderRepository extends GetxService {
  final DatabaseService _dbService = Get.find<DatabaseService>();
  final LoggingService _logger = Get.find<LoggingService>();

  Future<List<ProviderModel>> getAllProviders() async {
    try {
      final box = _dbService.providersBox;
      final List<dynamic> raw = box.values.toList();
      return raw
          .map((e) => _mapFromHive(e as Map))
          .whereType<ProviderModel>()
          .toList();
    } catch (e) {
      _logger.error('Failed to load providers', tag: 'ProviderRepository', error: e);
      throw DatabaseException(message: 'Failed to load providers', originalError: e);
    }
  }

  Future<ProviderModel?> getProviderById(String id) async {
    try {
      final box = _dbService.providersBox;
      final raw = box.get(id);
      if (raw == null) return null;
      return _mapFromHive(raw as Map);
    } catch (e) {
      _logger.error('Failed to get provider by id', tag: 'ProviderRepository', error: e);
      throw DatabaseException(message: 'Failed to get provider', originalError: e);
    }
  }

  Future<ProviderModel> createProvider(ProviderModel provider) async {
    try {
      final box = _dbService.providersBox;
      await box.put(provider.id, _mapToHive(provider));
      return provider;
    } catch (e) {
      _logger.error('Failed to create provider', tag: 'ProviderRepository', error: e);
      throw DatabaseException(message: 'Failed to create provider', originalError: e);
    }
  }

  Future<ProviderModel> updateProvider(ProviderModel provider) async {
    try {
      final box = _dbService.providersBox;
      final updated = provider.copyWith(updatedAt: DateTime.now());
      await box.put(updated.id, _mapToHive(updated));
      return updated;
    } catch (e) {
      _logger.error('Failed to update provider', tag: 'ProviderRepository', error: e);
      throw DatabaseException(message: 'Failed to update provider', originalError: e);
    }
  }

  Future<void> deleteProvider(String id) async {
    try {
      await _dbService.providersBox.delete(id);
    } catch (e) {
      _logger.error('Failed to delete provider', tag: 'ProviderRepository', error: e);
      throw DatabaseException(message: 'Failed to delete provider', originalError: e);
    }
  }

  Future<bool> providerNameExists(String name, {String? excludeId}) async {
    try {
      final providers = await getAllProviders();
      return providers.any((p) => p.name.toLowerCase() == name.toLowerCase() && p.id != excludeId);
    } catch (e) {
      return false;
    }
  }

  Map<String, dynamic> _mapToHive(ProviderModel model) {
    return {
      'id': model.id,
      'name': model.name,
      'providerType': model.providerType.name,
      'serverUrl': model.serverUrl,
      'username': model.username,
      'password': model.password,
      'macAddress': model.macAddress,
      'xmltvUrl': model.xmltvUrl,
      'notes': model.notes,
      'enabled': model.enabled,
      'favorite': model.favorite,
      'createdAt': model.createdAt.millisecondsSinceEpoch,
      'updatedAt': model.updatedAt.millisecondsSinceEpoch,
      'lastSync': model.lastSync?.millisecondsSinceEpoch,
      'status': model.status.name,
      'color': model.color,
      'icon': model.icon,
      'accountCreatedAt': model.accountCreatedAt?.millisecondsSinceEpoch,
      'accountExpiresAt': model.accountExpiresAt?.millisecondsSinceEpoch,
      'accountStatus': model.accountStatus,
      'accountIsTrial': model.accountIsTrial,
      'accountMaxConnections': model.accountMaxConnections,
    };
  }

  ProviderModel? _mapFromHive(Map<dynamic, dynamic> map) {
    try {
      final id = map['id'] as String?;
      final name = map['name'] as String?;
      final providerTypeStr = map['providerType'] as String?;
      final serverUrl = map['serverUrl'] as String?;
      final username = map['username'] as String?;
      final password = map['password'] as String?;
      final macAddress = map['macAddress'] as String?;
      final xmltvUrl = map['xmltvUrl'] as String?;
      final notes = map['notes'] as String?;
      final enabled = map['enabled'] as bool? ?? true;
      final favorite = map['favorite'] as bool? ?? false;
      final createdAtRaw = map['createdAt'] as int?;
      final updatedAtRaw = map['updatedAt'] as int?;
      final lastSyncRaw = map['lastSync'] as int?;
      final statusStr = map['status'] as String?;
      final color = map['color'] as String?;
      final icon = map['icon'] as String?;
      final accountCreatedAtRaw = map['accountCreatedAt'] as int?;
      final accountExpiresAtRaw = map['accountExpiresAt'] as int?;
      final accountStatus = map['accountStatus'] as String?;
      final accountIsTrial = map['accountIsTrial'] as bool?;
      final accountMaxConnections = map['accountMaxConnections'] as int?;

      if (id == null || name == null || providerTypeStr == null) return null;

      final providerType = ProviderType.values.firstWhere(
        (e) => e.name == providerTypeStr,
        orElse: () => ProviderType.custom,
      );

      final status = statusStr != null
          ? ProviderStatus.values.firstWhere(
              (e) => e.name == statusStr,
              orElse: () => ProviderStatus.inactive,
            )
          : ProviderStatus.inactive;

      return ProviderModel(
        id: id,
        name: name,
        providerType: providerType,
        serverUrl: serverUrl,
        username: username,
        password: password,
        macAddress: macAddress,
        xmltvUrl: xmltvUrl,
        notes: notes,
        enabled: enabled,
        favorite: favorite,
        createdAt: createdAtRaw != null
            ? DateTime.fromMillisecondsSinceEpoch(createdAtRaw)
            : DateTime.now(),
        updatedAt: updatedAtRaw != null
            ? DateTime.fromMillisecondsSinceEpoch(updatedAtRaw)
            : DateTime.now(),
        lastSync: lastSyncRaw != null
            ? DateTime.fromMillisecondsSinceEpoch(lastSyncRaw)
            : null,
        status: status,
        color: color,
        icon: icon,
        accountCreatedAt: accountCreatedAtRaw != null
            ? DateTime.fromMillisecondsSinceEpoch(accountCreatedAtRaw)
            : null,
        accountExpiresAt: accountExpiresAtRaw != null
            ? DateTime.fromMillisecondsSinceEpoch(accountExpiresAtRaw)
            : null,
        accountStatus: accountStatus,
        accountIsTrial: accountIsTrial,
        accountMaxConnections: accountMaxConnections,
      );
    } catch (e) {
      _logger.warning('Failed to map provider from hive', tag: 'ProviderRepository', error: e);
      return null;
    }
  }
}
