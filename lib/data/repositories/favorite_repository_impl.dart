import 'package:get/get.dart';
import 'package:stream_hub/core/services/cloud_sync_service.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/repositories/catalog_repository.dart';
import 'package:stream_hub/data/repositories/favorite_repository.dart';
import 'package:stream_hub/data/services/favorite_service.dart';

class FavoriteRepositoryImpl implements FavoriteRepository {
  final FavoriteService _service;
  final CatalogRepository? _catalogRepository;
  final Map<String, MediaItem> _itemCache = {};

  FavoriteRepositoryImpl(this._service, [this._catalogRepository]);

  void _triggerCloudSync() {
    if (Get.isRegistered<CloudSyncService>()) {
      Get.find<CloudSyncService>().schedulePush();
    }
  }

  @override
  Stream<void> watchUpdates() => _service.onChange;

  @override
  Future<void> add(MediaItem item) async {
    final favItem = item.copyWith(favorite: true);
    _itemCache[item.id] = favItem;
    await _service.addFavorite(item);
    if (_catalogRepository != null) {
      await _catalogRepository.upsertItems([favItem]);
    }
    _triggerCloudSync();
  }

  @override
  Future<void> remove(String itemId) async {
    _itemCache.remove(itemId);
    await _service.removeFavorite(itemId);
    _triggerCloudSync();
  }

  @override
  Future<List<MediaItem>> getAll() async {
    final ids = _service.favoriteIds;
    if (ids.isEmpty) return const [];

    final result = <MediaItem>[];
    final seen = <String>{};

    if (_catalogRepository != null) {
      try {
        final allItems = await _catalogRepository.getAllItems();
        for (final item in allItems) {
          if (ids.contains(item.id)) {
            final favItem = item.copyWith(favorite: true);
            _itemCache[item.id] = favItem;
            result.add(favItem);
            seen.add(item.id);
          }
        }
      } catch (_) {}
    }

    // Add persisted items from FavoriteService (stored in Hive)
    for (final item in _service.favoriteItems) {
      if (ids.contains(item.id) && !seen.contains(item.id)) {
        final favItem = item.copyWith(favorite: true);
        _itemCache[item.id] = favItem;
        result.add(favItem);
        seen.add(item.id);
      }
    }

    // Add any cached items not yet found in catalog or service
    for (final id in ids) {
      if (!seen.contains(id) && _itemCache.containsKey(id)) {
        result.add(_itemCache[id]!);
        seen.add(id);
      }
    }

    return result;
  }

  @override
  Future<bool> isFavorite(String itemId) async {
    return _service.isFavorite(itemId);
  }

  @override
  Future<void> clear() async {
    _itemCache.clear();
    await _service.clearFavorites();
  }

  @override
  Future<int> get count async => _service.favoriteCount;
}
