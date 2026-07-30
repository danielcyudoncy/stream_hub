import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/repositories/favorite_repository.dart';
import 'package:stream_hub/data/services/favorite_service.dart';

class FavoriteRepositoryImpl implements FavoriteRepository {
  final FavoriteService _service;
  final List<MediaItem> _items = [];

  FavoriteRepositoryImpl(this._service);

  @override
  Future<void> add(MediaItem item) async {
    _service.addFavorite(item);
    _items.removeWhere((i) => i.id == item.id);
    _items.add(item);
  }

  @override
  Future<void> remove(String itemId) async {
    _service.removeFavorite(itemId);
    _items.removeWhere((i) => i.id == itemId);
  }

  @override
  Future<List<MediaItem>> getAll() async {
    return List.unmodifiable(_items);
  }

  @override
  Future<bool> isFavorite(String itemId) async {
    return _service.isFavorite(itemId);
  }

  @override
  Future<void> clear() async {
    _service.clearFavorites();
    _items.clear();
  }

  @override
  Future<int> get count async => _service.favoriteCount;
}
