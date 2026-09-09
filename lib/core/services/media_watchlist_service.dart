import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:stream_hub/core/constants/app_constants.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/media/stream_matching_service.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/repositories/catalog_repository.dart';

class MediaWatchlistService extends GetxService {
  final LoggingService _logger;
  Box? _watchlistBox;
  StreamSubscription? _catalogSubscription;
  final RxSet<String> _wishlistIds = <String>{}.obs;

  MediaWatchlistService({LoggingService? logger})
      : _logger = logger ?? LoggingService();

  RxSet<String> get wishlistIds => _wishlistIds;

  Future<MediaWatchlistService> init() async {
    try {
      if (Hive.isBoxOpen(AppConstants.boxWatchlist)) {
        _watchlistBox = Hive.box(AppConstants.boxWatchlist);
      } else {
        _watchlistBox = await Hive.openBox(AppConstants.boxWatchlist);
      }
      _loadIds();
      _logger.info('MediaWatchlistService initialized with ${_wishlistIds.length} items', tag: 'MediaWatchlistService');
    } catch (e) {
      _logger.error('Failed to initialize MediaWatchlistService', tag: 'MediaWatchlistService', error: e);
    }
    return this;
  }

  void _loadIds() {
    if (_watchlistBox == null) return;
    _wishlistIds.clear();
    for (final key in _watchlistBox!.keys) {
      _wishlistIds.add(key.toString());
    }
  }

  String _extractTmdbId(MediaItem item) {
    return item.metadata['tmdb_id']?.toString() ??
        item.metadata['tmdbId']?.toString() ??
        item.id;
  }

  bool isInWatchlist(MediaItem item) {
    final id = _extractTmdbId(item);
    return _wishlistIds.contains(id) || _wishlistIds.contains(item.id);
  }

  Future<void> toggleWatchlist(MediaItem item) async {
    final tmdbId = _extractTmdbId(item);
    if (isInWatchlist(item)) {
      await removeFromWatchlist(tmdbId);
      await removeFromWatchlist(item.id);
    } else {
      await addToWatchlist(item);
    }
  }

  Future<void> addToWatchlist(MediaItem item) async {
    final tmdbId = _extractTmdbId(item);
    _wishlistIds.add(tmdbId);
    if (_watchlistBox != null) {
      await _watchlistBox!.put(tmdbId, {
        'id': item.id,
        'title': item.title,
        'mediaType': item.mediaType.name,
        'poster': item.poster,
        'backdrop': item.backdrop,
        'rating': item.rating,
        'metadata': item.metadata,
        'addedAt': DateTime.now().toIso8601String(),
      });
    }
    Get.snackbar(
      'Added to Wishlist',
      'We will notify you when "${item.title}" becomes available on your IPTV source.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.black87,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(16),
    );
  }

  Future<void> removeFromWatchlist(String tmdbId) async {
    _wishlistIds.remove(tmdbId);
    if (_watchlistBox != null) {
      await _watchlistBox!.delete(tmdbId);
    }
  }

  void startMatchingWatcher({
    required CatalogRepository catalogRepository,
    required StreamMatchingService streamMatchingService,
  }) {
    _catalogSubscription?.cancel();
    _catalogSubscription = catalogRepository.watchUpdates().listen((_) async {
      await _checkWishlistMatches(streamMatchingService);
    });
  }

  Future<void> _checkWishlistMatches(StreamMatchingService matchingService) async {
    if (_watchlistBox == null || _wishlistIds.isEmpty) return;

    for (final tmdbId in _wishlistIds.toList()) {
      final raw = _watchlistBox!.get(tmdbId);
      if (raw is Map) {
        final title = raw['title']?.toString() ?? '';
        final mediaTypeStr = raw['mediaType']?.toString();
        final mediaType = mediaTypeStr == 'series' ? MediaType.series : MediaType.movie;
        final metadata = Map<String, dynamic>.from(raw['metadata'] as Map? ?? {});
        final now = DateTime.now();
        final dummyItem = MediaItem(
          id: 'tmdb-probe-$tmdbId',
          title: title,
          providerId: 'tmdb',
          providerType: MediaSourceType.custom,
          mediaType: mediaType,
          metadata: metadata,
          createdAt: now,
          updatedAt: now,
        );

        final result = await matchingService.findMatch(dummyItem);
        if (result.isAvailable && result.matchedItem != null) {
          // Notify user!
          Get.snackbar(
            'Now Available!',
            '"$title" is now available to stream on ${result.matchedProviderName ?? "your IPTV source"}.',
            snackPosition: SnackPosition.TOP,
            backgroundColor: const Color(0xFF6200EE),
            colorText: Colors.white,
            duration: const Duration(seconds: 6),
            margin: const EdgeInsets.all(16),
          );
          // Remove from watchlist once available
          await removeFromWatchlist(tmdbId);
        }
      }
    }
  }

  @override
  void onClose() {
    _catalogSubscription?.cancel();
    super.onClose();
  }
}
