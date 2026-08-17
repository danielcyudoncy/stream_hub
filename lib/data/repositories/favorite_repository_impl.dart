import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/repositories/catalog_repository.dart';
import 'package:stream_hub/data/repositories/favorite_repository.dart';
import 'package:stream_hub/data/services/favorite_service.dart';

class FavoriteRepositoryImpl implements FavoriteRepository {
  final FavoriteService _service;
  final CatalogRepository? _catalogRepository;
  final Map<String, MediaItem> _itemCache = {};

  FavoriteRepositoryImpl(this._service, [this._catalogRepository]);

  @override
  Stream<void> watchUpdates() => _service.onChange;

  @override
  Future<void> add(MediaItem item) async {
    _itemCache[item.id] = item.copyWith(favorite: true);
    await _service.addFavorite(item);
  }

  @override
  Future<void> remove(String itemId) async {
    _itemCache.remove(itemId);
    await _service.removeFavorite(itemId);
  }

  @override
  Future<List<MediaItem>> getAll() async {
    final ids = _service.favoriteIds;
    if (ids.isEmpty) return const [];

    if (_catalogRepository != null) {
      try {
        final allItems = await _catalogRepository.getAllItems();
        final result = <MediaItem>[];
        final seen = <String>{};

        for (final item in allItems) {
          if (ids.contains(item.id)) {
            final favItem = item.copyWith(favorite: true);
            _itemCache[item.id] = favItem;
            result.add(favItem);
            seen.add(item.id);
          }
        }

        // Add any cached items not yet found in catalog
        for (final id in ids) {
          if (!seen.contains(id) && _itemCache.containsKey(id)) {
            result.add(_itemCache[id]!);
            seen.add(id);
          }
        }

        return result;
      } catch (_) {}
    }

    return _itemCache.values.where((item) => ids.contains(item.id)).toList();
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
