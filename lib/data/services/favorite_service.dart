import 'dart:async';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:stream_hub/core/helpers/profile_key_helper.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/services/active_profile_service.dart';

/// Profile-aware favorites storage service.
///
/// All Hive keys are namespaced via [ProfileKeyHelper] using the currently
/// active profile ID supplied by [ActiveProfileService].  When no profile is
/// active (empty ID) bare keys are used, preserving backward-compatibility
/// with existing single-profile data.
///
/// The service listens to [ActiveProfileService.profileId] and automatically
/// reloads its in-memory cache whenever the active profile changes.
class FavoriteService {
  final LoggingService logger;
  final Box? _box;

  final Set<String> _favoriteIds = {};
  final Map<String, DateTime> _favoritedAt = {};
  final StreamController<void> _changeController =
      StreamController<void>.broadcast();

  StreamSubscription<String>? _profileSub;

  Stream<void> get onChange => _changeController.stream;

  FavoriteService({LoggingService? logger, Box? box})
      : logger = logger ?? LoggingService(),
        _box = box {
    _loadFromBox();
    _listenForProfileChanges();
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  String get _profileId {
    if (Get.isRegistered<ActiveProfileService>()) {
      return Get.find<ActiveProfileService>().currentProfileId;
    }
    return '';
  }

  String _key(String itemId) => ProfileKeyHelper.favKey(_profileId, itemId);

  bool _ownsKey(String key) =>
      ProfileKeyHelper.isFavKeyForProfile(key, _profileId);

  String _itemId(String key) =>
      ProfileKeyHelper.extractFavItemId(key, _profileId);

  // ─── Profile switching ────────────────────────────────────────────────────

  void _listenForProfileChanges() {
    if (!Get.isRegistered<ActiveProfileService>()) return;
    _profileSub?.cancel();
    _profileSub = Get.find<ActiveProfileService>()
        .profileId
        .stream
        .listen((_) => _reloadForProfile());
  }

  void _reloadForProfile() {
    _favoriteIds.clear();
    _favoritedAt.clear();
    _loadFromBox();
    _changeController.add(null);
    logger.info(
      'FavoriteService: reloaded for profile "$_profileId"',
      tag: 'FavoriteService',
    );
  }

  // ─── Persistence ──────────────────────────────────────────────────────────

  void _loadFromBox() {
    if (_box == null) return;
    try {
      for (final key in _box.keys) {
        final keyStr = key.toString();
        if (!_ownsKey(keyStr)) continue; // skip other profiles' data

        final itemId = _itemId(keyStr);
        _favoriteIds.add(itemId);
        final val = _box.get(key);
        if (val is String) {
          _favoritedAt[itemId] = DateTime.tryParse(val) ?? DateTime.now();
        } else {
          _favoritedAt[itemId] = DateTime.now();
        }
      }
      logger.info(
        'Loaded ${_favoriteIds.length} favorites (profile: "$_profileId")',
        tag: 'FavoriteService',
      );
    } catch (e) {
      logger.warning(
        'Failed to load favorites from box',
        tag: 'FavoriteService',
        error: e,
      );
    }
  }

  // ─── Public API ───────────────────────────────────────────────────────────

  Future<void> addFavorite(MediaItem item) async {
    _favoriteIds.add(item.id);
    _favoritedAt[item.id] = DateTime.now();
    if (_box != null) {
      try {
        await _box.put(_key(item.id), DateTime.now().toIso8601String());
      } catch (e) {
        logger.warning(
          'Failed to persist favorite ${item.id}',
          tag: 'FavoriteService',
          error: e,
        );
      }
    }
    _changeController.add(null);
    logger.info('Added favorite: ${item.title}', tag: 'FavoriteService');
  }

  Future<void> removeFavorite(String itemId) async {
    _favoriteIds.remove(itemId);
    _favoritedAt.remove(itemId);
    if (_box != null) {
      try {
        await _box.delete(_key(itemId));
      } catch (e) {
        logger.warning(
          'Failed to delete favorite $itemId from storage',
          tag: 'FavoriteService',
          error: e,
        );
      }
    }
    _changeController.add(null);
    logger.info('Removed favorite: $itemId', tag: 'FavoriteService');
  }

  bool isFavorite(String itemId) => _favoriteIds.contains(itemId);

  List<MediaItem> getFavorites(List<MediaItem> allItems) {
    return allItems.where((item) => _favoriteIds.contains(item.id)).toList();
  }

  Set<String> get favoriteIds => Set.unmodifiable(_favoriteIds);

  int get favoriteCount => _favoriteIds.length;

  Future<void> clearFavorites() async {
    // Only remove keys that belong to the current profile.
    if (_box != null) {
      try {
        final keysToRemove = _box.keys
            .where((k) => _ownsKey(k.toString()))
            .toList();
        await _box.deleteAll(keysToRemove);
      } catch (e) {
        logger.warning(
          'Failed to clear favorites box for profile "$_profileId"',
          tag: 'FavoriteService',
          error: e,
        );
      }
    }
    _favoriteIds.clear();
    _favoritedAt.clear();
    _changeController.add(null);
    logger.info('Favorites cleared (profile: "$_profileId")', tag: 'FavoriteService');
  }

  void dispose() {
    _profileSub?.cancel();
    _changeController.close();
  }
}