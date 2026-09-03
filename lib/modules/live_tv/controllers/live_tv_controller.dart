import 'dart:async';

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/media/enums/playback_engine_preference.dart';
import 'package:stream_hub/core/media/player/exo_player_surface_view_adapter.dart';
import 'package:stream_hub/core/media/player/ijk_player_adapter.dart';
import 'package:stream_hub/core/media/player/vlc_player_adapter.dart';
import 'package:stream_hub/core/media/stream_resolver.dart';
import 'package:stream_hub/core/media/stream_resolvers/m3u_stream_resolver.dart';
import 'package:stream_hub/core/iptv/models/player_negotiation.dart';
import 'package:stream_hub/core/streaming/repositories/stream_repository.dart';
import 'package:stream_hub/data/repositories/history_repository.dart';
import 'package:stream_hub/modules/player/controllers/player_controller.dart';
import 'package:stream_hub/modules/settings/settings_controller.dart';
import '../../../data/models/media_item.dart';
import '../../../data/models/channel.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../data/repositories/favorite_repository.dart';
import '../../../data/repositories/provider_repository.dart';
import '../../../data/services/database_service.dart';
import '../../../core/media/media_engine.dart';
import '../../../core/media/media_library.dart';

class LiveTVController extends GetxController {
  final MediaEngine mediaEngine;
  final MediaLibrary mediaLibrary;
  final CatalogRepository catalogRepository;
  final FavoriteRepository? favoriteRepository;
  final HistoryRepository? historyRepository;
  final StreamResolver streamResolver;
  StreamSubscription? _catalogSubscription;

  LiveTVController({
    required this.mediaEngine,
    required this.mediaLibrary,
    required this.catalogRepository,
    this.favoriteRepository,
    this.historyRepository,
    StreamResolver? streamResolver,
  }) : streamResolver = streamResolver ?? M3UStreamResolver();

  final List<MediaItem> _allChannels = <MediaItem>[];
  final List<MediaItem> _allCategories = <MediaItem>[];

  final RxList<MediaItem> channels = <MediaItem>[].obs;
  final RxList<MediaItem> filteredChannels = <MediaItem>[].obs;
  final RxList<MediaItem> favorites = <MediaItem>[].obs;
  final RxList<MediaItem> recentChannels = <MediaItem>[].obs;
  final RxList<String> categories = <String>[].obs;
  final RxList<String> providers = <String>[].obs;
  final RxList<String> languages = <String>[].obs;
  final RxList<String> countries = <String>[].obs;
  final RxList<String> resolutions = <String>[].obs;

  final RxString selectedView = 'grid'.obs;
  final RxString selectedCategory = 'All Channels'.obs;
  final RxString selectedProvider = ''.obs;
  final RxString selectedLanguage = ''.obs;
  final RxString selectedCountry = ''.obs;
  final RxString selectedResolution = ''.obs;
  final RxString selectedSort = 'alphabetical'.obs;
  final RxString searchQuery = ''.obs;
  final RxBool showFavoritesOnly = false.obs;
  final RxBool showRecentlyAdded = false.obs;
  final RxBool isLoading = true.obs;
  final Rxn<MediaItem> featuredChannel = Rxn<MediaItem>();
  final Rxn<MediaItem> activePlayingChannel = Rxn<MediaItem>();
  PlayerController? inlinePlayerController;

  StreamSubscription? _favoriteSubscription;

  @override
  void onInit() {
    super.onInit();
    if (Get.isRegistered<ProviderRepository>()) {
      final providerRepo = Get.find<ProviderRepository>();
      selectedProvider.value = providerRepo.activeProviderId.value;
      ever(providerRepo.activeProviderId, (id) {
        if (selectedProvider.value != id) {
          setProvider(id);
        }
      });
    }
    _loadLiveTVData();
    _catalogSubscription =
        catalogRepository.watchUpdates().listen((_) => refresh());
    if (favoriteRepository != null) {
      _favoriteSubscription = favoriteRepository!
          .watchUpdates()
          .listen((_) => _syncFavoritesFromRepo());
    }
  }

  void _initInlinePlayer() {
    if (inlinePlayerController != null) return;

    // Resolve optimal in-tree embedded player engine based on user preference and device capability.
    // NativeActivity is an external Activity and cannot be embedded in a widget tree.
    PlaybackEngineKind chosenEngine = PlaybackEngineKind.mediaKit;
    final settingsCtrl = Get.isRegistered<SettingsController>()
        ? Get.find<SettingsController>()
        : null;
    if (settingsCtrl != null) {
      final pref = settingsCtrl.preferredPlayer.value;
      if (pref == PlaybackEnginePreference.exoPlayer &&
          ExoPlayerSurfaceViewAdapter.isSupported) {
        chosenEngine = PlaybackEngineKind.exoPlayer;
      } else if (pref == PlaybackEnginePreference.vlc &&
          VlcPlayerAdapter.isSupported) {
        chosenEngine = PlaybackEngineKind.vlc;
      } else if (pref == PlaybackEnginePreference.ijk &&
          IjkPlayerAdapter.isSupported) {
        chosenEngine = PlaybackEngineKind.ijk;
      } else if (pref == PlaybackEnginePreference.mediaKit) {
        chosenEngine = PlaybackEngineKind.mediaKit;
      } else {
        // Auto: Prefer ExoPlayer surface view on Android if supported, otherwise MediaKit
        if (ExoPlayerSurfaceViewAdapter.isSupported) {
          chosenEngine = PlaybackEngineKind.exoPlayer;
        } else {
          chosenEngine = PlaybackEngineKind.mediaKit;
        }
      }
    } else if (ExoPlayerSurfaceViewAdapter.isSupported) {
      chosenEngine = PlaybackEngineKind.exoPlayer;
    }

    inlinePlayerController = PlayerController(
      engineKind: chosenEngine,
      streamRepository: Get.isRegistered<StreamRepository>()
          ? Get.find<StreamRepository>()
          : null,
      historyRepository: historyRepository ??
          (Get.isRegistered<HistoryRepository>()
              ? Get.find<HistoryRepository>()
              : null),
      favoriteRepository: favoriteRepository,
      catalogRepository: catalogRepository,
    );
    inlinePlayerController!.onInit();
  }

  Future<void> _syncFavoritesFromRepo() async {
    final favList = await favoriteRepository?.getAll() ?? [];
    final favIds = favList.map((f) => f.id).toSet();

    for (var i = 0; i < _allChannels.length; i++) {
      final item = _allChannels[i];
      final isFav = favIds.contains(item.id);
      if (item.favorite != isFav) {
        _allChannels[i] = item.copyWith(favorite: isFav);
      }
    }

    _updateCategoriesAndFilters(favIds);
  }

  @override
  void onClose() {
    _catalogSubscription?.cancel();
    _favoriteSubscription?.cancel();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    inlinePlayerController?.stop();
    inlinePlayerController?.onClose();
    super.onClose();
  }

  /// Extracts a [MediaItem] from GetX navigation arguments, or returns null
  /// when no channel argument was provided.
  MediaItem? _extractChannelArg(dynamic args) {
    if (args is Map) {
      if (args['channel'] is MediaItem) return args['channel'] as MediaItem;
      if (args['item'] is MediaItem) return args['item'] as MediaItem;
    } else if (args is MediaItem) {
      return args;
    }
    return null;
  }

  void handleNavigationArguments() {
    final targetChannel = _extractChannelArg(Get.arguments);
    if (targetChannel == null) return;

    // Prefer the fully-loaded Channel instance from _allChannels (which has
    // streamUrl, correct metadata, etc.) over the raw MediaItem passed from
    // search results, which may be missing URL metadata.
    final matched = _allChannels.firstWhereOrNull((c) => c.id == targetChannel.id)
        ?? targetChannel;

    if (activePlayingChannel.value?.id != matched.id) {
      openChannel(matched);
      final matchCategory = matched.genres.isNotEmpty
          ? matched.genres.first
          : (matched.metadata['category_name']?.toString() ??
             matched.metadata['groupTitle']?.toString() ??
             matched.metadata['group']?.toString() ??
             '');

      if (matchCategory.isNotEmpty) {
        final targetCat = matchCategory.trim().toLowerCase();
        final foundCat = categories.firstWhereOrNull(
          (c) => c.toLowerCase() == targetCat,
        );
        if (foundCat != null) setCategory(foundCat);
      }
    }
  }

  Future<void> _loadLiveTVData() async {
    isLoading.value = true;
    try {
      final allItems = await catalogRepository.getAllItems();
      final liveChannels = allItems
          .where((item) => item.mediaType == MediaType.channel)
          .toList();

      final favList = await favoriteRepository?.getAll() ?? [];
      final favIds = favList.map((f) => f.id).toSet();

      final mappedChannels = liveChannels.map((item) {
        if (favIds.contains(item.id) || item.favorite) {
          return item.copyWith(favorite: true);
        }
        return item;
      }).toList();

      _allChannels
        ..clear()
        ..addAll(mappedChannels);

      final allCategories = await catalogRepository.getByType(MediaType.collection);
      _allCategories
        ..clear()
        ..addAll(allCategories);

      final providerSet = <String>{};
      for (final item in _allChannels) {
        if (item.providerId.isNotEmpty) {
          providerSet.add(item.providerId);
        }
        if (item.providerType.displayName.isNotEmpty) {
          providerSet.add(item.providerType.displayName);
        }
      }
      providers.assignAll(providerSet.toList()..sort());

      await _loadRecentChannels();
      _updateCategoriesAndFilters(favIds);

      // Process any channel passed via navigation arguments now that
      // _allChannels is fully loaded, so firstWhereOrNull finds the correct
      // Channel instance (with streamUrl) instead of falling back to the raw
      // MediaItem from the search results.
      final hasChannelArg = _extractChannelArg(Get.arguments) != null;
      if (hasChannelArg) {
        handleNavigationArguments();
      } else {
        // Restore last-watched channel from history if available
        final historyRepo = historyRepository ??
            (Get.isRegistered<HistoryRepository>()
                ? Get.find<HistoryRepository>()
                : null);
        if (historyRepo != null) {
          final recentItems = await historyRepo.getRecent(limit: 20);
          final lastWatched = recentItems.firstWhereOrNull(
              (item) => item.mediaType == MediaType.channel);
          if (lastWatched != null) {
            final matched = _allChannels
                .firstWhereOrNull((c) => c.id == lastWatched.id);
            featuredChannel.value = matched ?? lastWatched;
          } else if (_allChannels.isNotEmpty) {
            featuredChannel.value = _allChannels.first;
          }
        } else if (_allChannels.isNotEmpty) {
          featuredChannel.value = _allChannels.first;
        }
      }
    } catch (e) {
      // Log error
    } finally {
      isLoading.value = false;
    }
  }

  Set<String> _loadHiddenCategories() {
    try {
      if (Get.isRegistered<DatabaseService>()) {
        final db = Get.find<DatabaseService>();
        final saved = db.settingsBox.get('hidden_categories');
        if (saved is List) {
          final set = saved.cast<String>().toSet();
          final expanded = <String>{...set};
          for (final raw in set) {
            final trimmed = raw.trim();
            expanded.add(trimmed);
            expanded.add(trimmed.toLowerCase());
            expanded.add(trimmed.toLowerCase().replaceAll(' ', '_'));
            expanded.add(trimmed.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), ''));

            for (final cat in _allCategories) {
              if (cat.id == raw ||
                  cat.title == raw ||
                  cat.title.toLowerCase() == raw.toLowerCase() ||
                  cat.title.toLowerCase().replaceAll(' ', '_') == raw.toLowerCase()) {
                expanded.add(cat.id);
                expanded.add(cat.title);
                expanded.add(cat.title.trim());
                expanded.add(cat.title.toLowerCase());
                expanded.add(cat.title.toLowerCase().replaceAll(' ', '_'));
                expanded.add(cat.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), ''));
              }
            }
          }
          return expanded;
        }
      }
    } catch (_) {}
    return <String>{};
  }

  Set<String> _loadHiddenChannels() {
    try {
      if (Get.isRegistered<DatabaseService>()) {
        final db = Get.find<DatabaseService>();
        final saved = db.settingsBox.get('hidden_channels');
        if (saved is List) {
          return saved.cast<String>().toSet();
        }
      }
    } catch (_) {}
    return <String>{};
  }

  bool _isCategoryHidden(String categoryName, Set<String> hiddenCategories) {
    if (hiddenCategories.isEmpty) return false;
    final trimmed = categoryName.trim();
    if (hiddenCategories.contains(trimmed)) return true;
    final lower = trimmed.toLowerCase();
    if (hiddenCategories.contains(lower)) return true;
    final underscore = lower.replaceAll(' ', '_');
    if (hiddenCategories.contains(underscore)) return true;
    final alphaNumeric = lower.replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (alphaNumeric.isNotEmpty && hiddenCategories.contains(alphaNumeric)) {
      return true;
    }
    return false;
  }

  bool _isChannelHidden(MediaItem item, Set<String> hiddenChannels, Set<String> hiddenCategories) {
    if (hiddenChannels.contains(item.id)) return true;
    if (hiddenCategories.isEmpty) return false;

    final genreId = item.metadata['genreId']?.toString();
    if (genreId != null && _isCategoryHidden(genreId, hiddenCategories)) return true;

    final catId = item.metadata['category_id']?.toString();
    if (catId != null && _isCategoryHidden(catId, hiddenCategories)) return true;

    for (final genre in item.genres) {
      if (_isCategoryHidden(genre, hiddenCategories)) return true;
    }
    final genreMeta = item.metadata['genre']?.toString();
    if (genreMeta != null && _isCategoryHidden(genreMeta, hiddenCategories)) {
      return true;
    }

    final catMeta = item.metadata['category_name']?.toString();
    if (catMeta != null && _isCategoryHidden(catMeta, hiddenCategories)) {
      return true;
    }

    return false;
  }

  void syncHiddenCategories() {
    _updateCategoriesAndFilters();
  }

  void _updateCategoriesAndFilters([Set<String>? favIds]) {
    final hiddenCategories = _loadHiddenCategories();
    final hiddenChannels = _loadHiddenChannels();

    final unhiddenChannels = _allChannels
        .where((item) => !_isChannelHidden(item, hiddenChannels, hiddenCategories))
        .toList();

    final activeChannels = selectedProvider.value.isEmpty
        ? List<MediaItem>.from(unhiddenChannels)
        : unhiddenChannels.where((item) {
            return item.providerId == selectedProvider.value ||
                item.providerType.displayName == selectedProvider.value ||
                item.providerType.name == selectedProvider.value;
          }).toList();

    channels.assignAll(activeChannels);

    if (activeChannels.isNotEmpty) {
      final currentFeatured = featuredChannel.value;
      if (currentFeatured == null ||
          !activeChannels.any((c) => c.id == currentFeatured.id)) {
        final liveCandidate =
            activeChannels.firstWhereOrNull((c) => c is Channel && c.isLive);
        featuredChannel.value = liveCandidate ?? activeChannels.first;
      }
    } else {
      featuredChannel.value = null;
    }

    final effectiveFavIds = favIds ??
        (favoriteRepository != null
            ? (favorites.map((f) => f.id).toSet())
            : <String>{});

    favorites.assignAll(
      activeChannels
          .where((item) =>
              effectiveFavIds.contains(item.id) || item.favorite)
          .toList(),
    );

    final languageSet = <String>{};
    final countrySet = <String>{};
    final resolutionSet = <String>{};
    final categorySet = <String>{};

    for (final item in activeChannels) {
      if (item.language != null && item.language!.isNotEmpty) {
        languageSet.add(item.language!);
      }
      if (item.country != null && item.country!.isNotEmpty) {
        countrySet.add(item.country!);
      }
      final res = item.metadata['resolution'] as String?;
      if (res != null && res.isNotEmpty) {
        resolutionSet.add(res);
      }
      for (final genre in item.genres) {
        if (genre.trim().isNotEmpty && !_isCategoryHidden(genre, hiddenCategories)) {
          categorySet.add(genre.trim());
        }
      }
      final genreMeta = item.metadata['genre']?.toString();
      if (genreMeta != null &&
          genreMeta.trim().isNotEmpty &&
          !_isCategoryHidden(genreMeta, hiddenCategories)) {
        categorySet.add(genreMeta.trim());
      }
      final catMeta = item.metadata['category_name']?.toString();
      if (catMeta != null &&
          catMeta.trim().isNotEmpty &&
          !_isCategoryHidden(catMeta, hiddenCategories)) {
        categorySet.add(catMeta.trim());
      }
    }

    for (final cat in _allCategories) {
      final isLive = cat.metadata['type'] == 'live' || cat.metadata['type'] == null;
      final matchesProvider = selectedProvider.value.isEmpty ||
          cat.providerId == selectedProvider.value ||
          cat.providerType.displayName == selectedProvider.value ||
          cat.providerType.name == selectedProvider.value;
      if (isLive &&
          matchesProvider &&
          cat.title.trim().isNotEmpty &&
          !_isCategoryHidden(cat.title, hiddenCategories) &&
          !hiddenCategories.contains(cat.id)) {
        categorySet.add(cat.title.trim());
      }
    }

    final sortedCategories = categorySet.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    categories.assignAll(['All Channels', '★ Favorites', '🕒 Recent', ...sortedCategories]);

    if (!categories.contains(selectedCategory.value)) {
      selectedCategory.value = 'All Channels';
    }

    languages.assignAll(languageSet.toList()..sort());
    countries.assignAll(countrySet.toList()..sort());
    resolutions.assignAll(resolutionSet.toList()..sort());

    _applyFilters();
  }

  Future<void> _loadRecentChannels() async {
    try {
      final historyRepo = historyRepository ??
          (Get.isRegistered<HistoryRepository>()
              ? Get.find<HistoryRepository>()
              : null);
      if (historyRepo != null) {
        final recentItems = await historyRepo.getRecent(limit: 50);
        final channelItems = recentItems
            .where((item) => item.mediaType == MediaType.channel)
            .toList();
        recentChannels.assignAll(channelItems);
      }
    } catch (_) {}
  }

  void setView(String view) {
    selectedView.value = view;
  }

  void setCategory(String category) {
    selectedCategory.value = category;
    _applyFilters();
  }

  void setSearchQuery(String query) {
    searchQuery.value = query;
    _applyFilters();
  }

  void setFeaturedChannel(MediaItem channel) {
    featuredChannel.value = channel;
  }

  void setProvider(String provider) {
    if (selectedProvider.value != provider) {
      selectedProvider.value = provider;
    }
    selectedCategory.value = 'All Channels';
    if (Get.isRegistered<ProviderRepository>()) {
      final providerRepo = Get.find<ProviderRepository>();
      if (providerRepo.activeProviderId.value != provider) {
        providerRepo.setActiveProviderId(provider);
      }
    }
    _updateCategoriesAndFilters();
  }

  void setLanguage(String language) {
    selectedLanguage.value = language;
    _applyFilters();
  }

  void setCountry(String country) {
    selectedCountry.value = country;
    _applyFilters();
  }

  void setResolution(String resolution) {
    selectedResolution.value = resolution;
    _applyFilters();
  }

  void setSort(String sort) {
    selectedSort.value = sort;
    _applyFilters();
  }

  void setFavoritesOnly(bool value) {
    showFavoritesOnly.value = value;
    _applyFilters();
  }

  void setRecentlyAdded(bool value) {
    showRecentlyAdded.value = value;
    _applyFilters();
  }

  void _applyFilters() {
    var result = List<MediaItem>.from(channels);

    if (searchQuery.value.trim().isNotEmpty) {
      final q = searchQuery.value.trim().toLowerCase();
      result = result.where((item) {
        final titleMatch = item.title.toLowerCase().contains(q);
        final subtitleMatch = item.subtitle != null && item.subtitle!.toLowerCase().contains(q);
        final genreMatch = item.genres.any((g) => g.toLowerCase().contains(q));
        final numberMatch = item is Channel && item.number != null && item.number!.toLowerCase().contains(q);
        return titleMatch || subtitleMatch || genreMatch || numberMatch;
      }).toList();
    }

    if (selectedCategory.value == '★ Favorites') {
      final favIds = favorites.map((f) => f.id).toSet();
      result = result
          .where((item) => favIds.contains(item.id) || item.favorite)
          .toList();
    } else if (selectedCategory.value == '🕒 Recent') {
      final recentIds = recentChannels.map((r) => r.id).toSet();
      result = result.where((item) => recentIds.contains(item.id)).toList();
      final idOrder = {
        for (int i = 0; i < recentChannels.length; i++) recentChannels[i].id: i
      };
      result.sort((a, b) => (idOrder[a.id] ?? 999).compareTo(idOrder[b.id] ?? 999));
    } else if (selectedCategory.value != 'All Channels' &&
        selectedCategory.value.trim().isNotEmpty) {
      final selectedCat = selectedCategory.value.trim().toLowerCase();

      // Find all associated category IDs and titles from _allCategories
      final matchingCatIds = <String>{};
      for (final cat in _allCategories) {
        if (cat.title.trim().toLowerCase() == selectedCat ||
            cat.id.trim().toLowerCase() == selectedCat) {
          matchingCatIds.add(cat.id.trim().toLowerCase());
          matchingCatIds.add(cat.title.trim().toLowerCase());
        }
      }

      result = result.where((item) {
        // Direct genre / category name match
        for (final g in item.genres) {
          final gLower = g.trim().toLowerCase();
          if (gLower == selectedCat || matchingCatIds.contains(gLower)) return true;
        }

        final genreMeta =
            item.metadata['genre']?.toString().trim().toLowerCase();
        if (genreMeta != null &&
            (genreMeta == selectedCat || matchingCatIds.contains(genreMeta))) {
          return true;
        }

        final catNameMeta =
            item.metadata['category_name']?.toString().trim().toLowerCase();
        if (catNameMeta != null &&
            (catNameMeta == selectedCat || matchingCatIds.contains(catNameMeta))) {
          return true;
        }

        final catIdMeta =
            item.metadata['category_id']?.toString().trim().toLowerCase();
        if (catIdMeta != null &&
            (catIdMeta == selectedCat || matchingCatIds.contains(catIdMeta))) {
          return true;
        }

        final genreIdMeta =
            item.metadata['genreId']?.toString().trim().toLowerCase();
        if (genreIdMeta != null &&
            (genreIdMeta == selectedCat || matchingCatIds.contains(genreIdMeta))) {
          return true;
        }

        final groupTitleMeta =
            item.metadata['group_title']?.toString().trim().toLowerCase() ??
            item.metadata['group-title']?.toString().trim().toLowerCase() ??
            item.metadata['group']?.toString().trim().toLowerCase();
        if (groupTitleMeta != null &&
            (groupTitleMeta == selectedCat || matchingCatIds.contains(groupTitleMeta))) {
          return true;
        }

        return false;
      }).toList();
    }

    if (selectedProvider.value.isNotEmpty) {
      result = result
          .where((item) =>
              item.providerId == selectedProvider.value ||
              item.providerType.displayName == selectedProvider.value)
          .toList();
    }

    if (selectedLanguage.value.isNotEmpty) {
      result = result
          .where((item) => item.language == selectedLanguage.value)
          .toList();
    }

    if (selectedCountry.value.isNotEmpty) {
      result = result
          .where((item) => item.country == selectedCountry.value)
          .toList();
    }

    if (selectedResolution.value.isNotEmpty) {
      result = result
          .where((item) =>
              item.metadata['resolution'] == selectedResolution.value)
          .toList();
    }

    if (showFavoritesOnly.value) {
      final favIds = favorites.map((f) => f.id).toSet();
      result = result.where((item) => favIds.contains(item.id)).toList();
    }

    if (showRecentlyAdded.value) {
      result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    switch (selectedSort.value) {
      case 'alphabetical':
        result.sort((a, b) =>
            a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case 'recentlyAdded':
        result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'provider':
        result.sort((a, b) => a.providerType.displayName
            .compareTo(b.providerType.displayName));
        break;
      case 'country':
        result.sort((a, b) => (a.country ?? '').compareTo(b.country ?? ''));
        break;
    }

    filteredChannels.assignAll(result);
  }

  void openChannel(MediaItem channel) {
    activePlayingChannel.value = channel;
    featuredChannel.value = channel;

    // Defer heavy player initialization and state setup to the next frame
    // to allow the UI to immediately paint the active (glowing) channel state
    Future.delayed(Duration.zero, () {
      _initInlinePlayer();

      // Record last played channel in history
      final historyRepo = historyRepository ??
          (Get.isRegistered<HistoryRepository>()
              ? Get.find<HistoryRepository>()
              : null);
      if (historyRepo != null) {
        historyRepo.add(channel).then((_) => _loadRecentChannels());
      }

      final itemsToPass = filteredChannels.isNotEmpty
          ? filteredChannels.toList()
          : (channels.isNotEmpty ? channels.toList() : [channel]);
      inlinePlayerController?.setChannelList(itemsToPass, currentId: channel.id);
    });
  }

  final RxBool isFullscreenMode = false.obs;
  DateTime lastFullscreenEntered = DateTime.fromMillisecondsSinceEpoch(0);

  /// Plays the next channel in the filtered/active channel list for TV remote zapping.
  void playNextChannel() {
    final list = filteredChannels.isNotEmpty ? filteredChannels : channels;
    if (list.isEmpty) return;
    final current = activePlayingChannel.value;
    if (current == null) {
      openChannel(list.first);
      return;
    }
    final currentIndex = list.indexWhere((c) => c.id == current.id);
    final nextIndex = currentIndex < 0 ? 0 : (currentIndex + 1) % list.length;
    openChannel(list[nextIndex]);
  }

  /// Plays the previous channel in the filtered/active channel list for TV remote zapping.
  void playPreviousChannel() {
    final list = filteredChannels.isNotEmpty ? filteredChannels : channels;
    if (list.isEmpty) return;
    final current = activePlayingChannel.value;
    if (current == null) {
      openChannel(list.last);
      return;
    }
    final currentIndex = list.indexWhere((c) => c.id == current.id);
    final prevIndex = currentIndex <= 0 ? list.length - 1 : currentIndex - 1;
    openChannel(list[prevIndex]);
  }

  void stopInlinePlayer() {
    activePlayingChannel.value = null;
    isFullscreenMode.value = false;
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    inlinePlayerController?.stop();
  }

  void expandToFullscreen() {
    if (activePlayingChannel.value != null || featuredChannel.value != null) {
      if (activePlayingChannel.value == null && featuredChannel.value != null) {
        openChannel(featuredChannel.value!);
      }
      lastFullscreenEntered = DateTime.now();
      isFullscreenMode.value = true;
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  void exitFullscreen() {
    isFullscreenMode.value = false;
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  void toggleFullscreen() {
    if (isFullscreenMode.value) {
      exitFullscreen();
    } else {
      expandToFullscreen();
    }
  }

  Future<void> toggleFavorite(MediaItem item) async {
    final isFav = favorites.any((f) => f.id == item.id) || item.favorite;
    final updatedItem = item.copyWith(favorite: !isFav);

    if (isFav) {
      favorites.removeWhere((f) => f.id == item.id);
      await favoriteRepository?.remove(item.id);
    } else {
      favorites.add(updatedItem);
      await favoriteRepository?.add(updatedItem);
    }

    // Update in channels and filteredChannels in-place without triggering full reload
    final channelIdx = channels.indexWhere((c) => c.id == item.id);
    if (channelIdx != -1) {
      channels[channelIdx] = updatedItem;
    }

    final filteredIdx = filteredChannels.indexWhere((c) => c.id == item.id);
    if (filteredIdx != -1) {
      filteredChannels[filteredIdx] = updatedItem;
    }

    if (featuredChannel.value?.id == item.id) {
      featuredChannel.value = updatedItem;
    }

    if (showFavoritesOnly.value) {
      _applyFilters();
    }
  }

  @override
  void refresh() {
    _loadLiveTVData();
  }
}
