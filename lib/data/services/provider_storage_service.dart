import 'dart:async';

import 'package:get/get.dart';
import 'package:stream_hub/core/errors/exceptions.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/repositories/provider_repository.dart';
import 'package:stream_hub/modules/provider_manager/models/provider_model.dart';

class ProviderStorageService extends GetxService {
  final ProviderRepository _repository;
  final LoggingService _logger = Get.find<LoggingService>();

  ProviderStorageService(this._repository);

  Future<List<ProviderModel>> getAllProviders() async {
    try {
      return await _repository.getAllProviders();
    } catch (e) {
      _logger.error('Failed to get all providers', tag: 'ProviderStorageService', error: e);
      throw DatabaseException(message: 'Failed to get providers', originalError: e);
    }
  }

  Future<ProviderModel?> getProviderById(String id) async {
    try {
      return await _repository.getProviderById(id);
    } catch (e) {
      _logger.error('Failed to get provider', tag: 'ProviderStorageService', error: e);
      throw DatabaseException(message: 'Failed to get provider', originalError: e);
    }
  }

  Future<ProviderModel> createProvider(ProviderModel provider) async {
    try {
      return await _repository.createProvider(provider);
    } catch (e) {
      _logger.error('Failed to create provider', tag: 'ProviderStorageService', error: e);
      throw DatabaseException(message: 'Failed to create provider', originalError: e);
    }
  }

  Future<ProviderModel> updateProvider(ProviderModel provider) async {
    try {
      return await _repository.updateProvider(provider);
    } catch (e) {
      _logger.error('Failed to update provider', tag: 'ProviderStorageService', error: e);
      throw DatabaseException(message: 'Failed to update provider', originalError: e);
    }
  }

  Future<void> deleteProvider(String id) async {
    try {
      await _repository.deleteProvider(id);
    } catch (e) {
      _logger.error('Failed to delete provider', tag: 'ProviderStorageService', error: e);
      throw DatabaseException(message: 'Failed to delete provider', originalError: e);
    }
  }

  Future<void> deleteAllProviders() async {
    try {
      final providers = await getAllProviders();
      for (final provider in providers) {
        await _repository.deleteProvider(provider.id);
      }
    } catch (e) {
      _logger.error('Failed to delete all providers', tag: 'ProviderStorageService', error: e);
      throw DatabaseException(message: 'Failed to delete all providers', originalError: e);
    }
  }

  Future<int> getProviderCount() async {
    try {
      final providers = await getAllProviders();
      return providers.length;
    } catch (e) {
      return 0;
    }
  }

  Future<List<ProviderModel>> getEnabledProviders() async {
    try {
      final all = await getAllProviders();
      return all.where((p) => p.enabled).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<ProviderModel>> getFavoriteProviders() async {
    try {
      final all = await getAllProviders();
      return all.where((p) => p.favorite).toList();
    } catch (e) {
      return [];
    }
  }
}
