import 'dart:async';
import 'dart:math';

import 'package:get/get.dart';
import 'package:stream_hub/core/errors/exceptions.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/models/cache_info.dart';
import 'package:stream_hub/data/repositories/provider_repository.dart';
import 'package:stream_hub/data/services/cache_service.dart';
import 'package:stream_hub/data/services/provider_storage_service.dart';
import 'package:stream_hub/data/services/provider_sync_service.dart';
import 'package:stream_hub/data/services/settings_service.dart';
import 'package:stream_hub/modules/provider_manager/models/provider_enums.dart';
import 'package:stream_hub/modules/provider_manager/models/provider_model.dart';

class ProviderManagerController extends GetxController {
  final ProviderRepository _repository;
  // ignore: unused_field
  final ProviderStorageService _storageService;
  final CacheService _cacheService;
  // ignore: unused_field
  final SettingsService _settingsService;
  final ProviderSyncService _syncService;
  final LoggingService _logger = Get.find<LoggingService>();

  ProviderManagerController({
    required ProviderRepository repository,
    required ProviderStorageService storageService,
    required CacheService cacheService,
    required SettingsService settingsService,
    required ProviderSyncService syncService,
  }) : _repository = repository,
       _storageService = storageService,
       _cacheService = cacheService,
       _settingsService = settingsService,
       _syncService = syncService;

  final RxList<ProviderModel> providers = <ProviderModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxString searchQuery = ''.obs;
  final Rx<ProviderSortField> sortField = ProviderSortField.dateAdded.obs;
  final Rx<ProviderFilterType> filterType = ProviderFilterType.all.obs;
  final Rx<ProviderType?> filterProviderType = Rx<ProviderType?>(null);
  final Rx<CacheInfo?> cacheInfo = Rx<CacheInfo?>(null);
  final RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadProviders();
    _loadCacheInfo();
  }

  Future<void> loadProviders() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final all = await _repository.getAllProviders();
      providers.value = _applySorting(_applyFiltering(all));
    } on ApplicationException catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = 'Failed to load providers.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> createProvider(ProviderModel provider) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final exists = await _repository.providerNameExists(provider.name);
      if (exists) {
        throw const ValidationException(message: 'A provider with this name already exists.');
      }
      await _repository.createProvider(provider);
      await loadProviders();
      unawaited(_syncProvider(provider));
      Get.snackbar(
        'Success',
        'Provider "${provider.name}" created. Importing playlist...',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Get.theme.colorScheme.surfaceContainerHighest,
        colorText: Get.theme.colorScheme.onSurface,
      );
    } on ApplicationException catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = 'Failed to create provider.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _syncProvider(ProviderModel provider) async {
    final result = await _syncService.syncProvider(provider);
    if (!result.success) {
      errorMessage.value = result.message ?? 'Sync failed.';
      Get.snackbar(
        'Sync Failed',
        result.message ?? 'Sync failed.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Get.theme.colorScheme.errorContainer,
        colorText: Get.theme.colorScheme.onErrorContainer,
      );
    }
    await loadProviders();
  }

  Future<void> updateProvider(ProviderModel provider) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final exists = await _repository.providerNameExists(provider.name, excludeId: provider.id);
      if (exists) {
        throw const ValidationException(message: 'A provider with this name already exists.');
      }
      final updated = await _repository.updateProvider(provider);
      await loadProviders();
      unawaited(_syncProvider(updated));
      Get.snackbar(
        'Success',
        'Provider "${provider.name}" updated.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Get.theme.colorScheme.surfaceContainerHighest,
        colorText: Get.theme.colorScheme.onSurface,
      );
    } on ApplicationException catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = 'Failed to update provider.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> deleteProvider(String id) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      await _repository.deleteProvider(id);
      await loadProviders();
      return true;
    } on ApplicationException catch (e) {
      errorMessage.value = e.message;
      return false;
    } catch (e) {
      errorMessage.value = 'Failed to delete provider.';
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Shows the deletion confirmation snackbar. Kept separate from
  /// [deleteProvider] so the caller can navigate away first: in GetX, showing a
  /// snackbar and then calling `Get.back()` immediately swallows the back
  /// navigation, leaving the app stuck on the removed provider's page.
  void showDeletedSnackbar(String name) {
    try {
      Get.snackbar(
        'Deleted',
        'Provider "$name" removed.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Get.theme.colorScheme.surfaceContainerHighest,
        colorText: Get.theme.colorScheme.onSurface,
      );
    } catch (_) {
      // Intentionally ignored; the snackbar is purely cosmetic.
    }
  }

  Future<void> duplicateProvider(String id) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final original = await _repository.getProviderById(id);
      if (original == null) {
        throw const ValidationException(message: 'Provider not found.');
      }
      final duplicate = ProviderModel(
        id: _generateId(),
        name: '${original.name} (Copy)',
        providerType: original.providerType,
        serverUrl: original.serverUrl,
        username: original.username,
        password: original.password,
        macAddress: original.macAddress,
        xmltvUrl: original.xmltvUrl,
        notes: original.notes,
        enabled: original.enabled,
        favorite: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        lastSync: null,
        status: ProviderStatus.inactive,
        color: original.color,
        icon: original.icon,
      );
      await _repository.createProvider(duplicate);
      await loadProviders();
      unawaited(_syncProvider(duplicate));
      Get.snackbar(
        'Duplicated',
        'Provider duplicated successfully.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Get.theme.colorScheme.surfaceContainerHighest,
        colorText: Get.theme.colorScheme.onSurface,
      );
    } on ApplicationException catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = 'Failed to duplicate provider.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> syncProviderById(String id) async {
    try {
      final provider = await _repository.getProviderById(id);
      if (provider == null) return;
      await _syncProvider(provider);
    } catch (e) {
      _logger.warning('Failed to sync provider', tag: 'ProviderManagerController', error: e);
    }
  }

  Future<void> toggleFavorite(String id) async {
    try {
      final provider = await _repository.getProviderById(id);
      if (provider == null) return;
      final updated = provider.copyWith(favorite: !provider.favorite);
      await _repository.updateProvider(updated);
      await loadProviders();
    } catch (e) {
      _logger.warning('Failed to toggle favorite', tag: 'ProviderManagerController', error: e);
    }
  }

  Future<void> toggleEnabled(String id) async {
    try {
      final provider = await _repository.getProviderById(id);
      if (provider == null) return;
      final updated = provider.copyWith(enabled: !provider.enabled);
      await _repository.updateProvider(updated);
      await loadProviders();
    } catch (e) {
      _logger.warning('Failed to toggle enabled', tag: 'ProviderManagerController', error: e);
    }
  }

  void updateSearchQuery(String query) {
    searchQuery.value = query.trim();
    _refreshList();
  }

  void updateSortField(ProviderSortField field) {
    sortField.value = field;
    _refreshList();
  }

  void updateFilterType(ProviderFilterType type) {
    filterType.value = type;
    _refreshList();
  }

  void updateFilterProviderType(ProviderType? type) {
    filterProviderType.value = type;
    _refreshList();
  }

  Future<void> refreshCacheInfo() async {
    await _loadCacheInfo();
  }

  List<ProviderModel> getFilteredProviders() {
    final all = providers;
    return _applySorting(_applyFiltering(all));
  }

  List<ProviderModel> _applyFiltering(List<ProviderModel> list) {
    var filtered = list;

    if (searchQuery.value.isNotEmpty) {
      final query = searchQuery.value.toLowerCase();
      filtered = filtered.where((p) {
        return p.name.toLowerCase().contains(query) ||
            p.providerType.displayName.toLowerCase().contains(query) ||
            (p.serverUrl ?? '').toLowerCase().contains(query) ||
            (p.notes ?? '').toLowerCase().contains(query);
      }).toList();
    }

    switch (filterType.value) {
      case ProviderFilterType.enabled:
        filtered = filtered.where((p) => p.enabled).toList();
        break;
      case ProviderFilterType.disabled:
        filtered = filtered.where((p) => !p.enabled).toList();
        break;
      case ProviderFilterType.favorites:
        filtered = filtered.where((p) => p.favorite).toList();
        break;
      case ProviderFilterType.all:
        break;
    }

    if (filterProviderType.value != null) {
      filtered = filtered.where((p) => p.providerType == filterProviderType.value).toList();
    }

    return filtered;
  }

  List<ProviderModel> _applySorting(List<ProviderModel> list) {
    final sorted = List<ProviderModel>.from(list);
    switch (sortField.value) {
      case ProviderSortField.name:
        sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case ProviderSortField.dateAdded:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case ProviderSortField.lastUpdated:
        sorted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
      case ProviderSortField.providerType:
        sorted.sort((a, b) => a.providerType.displayName.compareTo(b.providerType.displayName));
        break;
    }
    return sorted;
  }

  void _refreshList() {
    providers.assignAll(_applySorting(_applyFiltering(List.from(providers))));
  }

  Future<void> _loadCacheInfo() async {
    try {
      final info = await _cacheService.calculateCacheSize();
      cacheInfo.value = info;
    } catch (e) {
      _logger.warning('Failed to load cache info', tag: 'ProviderManagerController', error: e);
    }
  }

  String _generateId() {
    final random = Random();
    final chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return 'provider_${DateTime.now().millisecondsSinceEpoch}_${List.generate(8, (_) => chars[random.nextInt(chars.length)]).join()}';
  }
}
