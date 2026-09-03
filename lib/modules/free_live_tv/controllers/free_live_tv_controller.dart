import 'dart:async';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/helpers/platform_helper.dart';
import 'package:stream_hub/core/iptv/models/player_negotiation.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/enums/playback_engine_preference.dart';
import 'package:stream_hub/core/media/enums/playback_state.dart';
import 'package:stream_hub/core/media/player/exo_player_surface_view_adapter.dart';
import 'package:stream_hub/core/media/player/ijk_player_adapter.dart';
import 'package:stream_hub/core/media/player/vlc_player_adapter.dart';
import 'package:stream_hub/core/streaming/repositories/stream_repository.dart';
import 'package:stream_hub/data/models/free_tv_channel.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/repositories/free_tv_repository.dart';
import 'package:stream_hub/modules/player/controllers/player_controller.dart';
import 'package:stream_hub/modules/settings/settings_controller.dart';

class FreeLiveTvController extends GetxController {
  final FreeTvRepository repository;
  final LoggingService _logger;

  FreeLiveTvController({
    FreeTvRepository? repository,
    LoggingService? logger,
  })  : repository = repository ?? FreeTvRepository(),
        _logger = logger ?? LoggingService();

  final List<FreeTvChannel> _allChannels = [];
  final List<FreeTvChannel> _recommendedAll = [];

  final RxList<FreeTvChannel> channels = <FreeTvChannel>[].obs;
  final RxList<FreeTvChannel> filteredChannels = <FreeTvChannel>[].obs;
  final RxList<FreeTvChannel> recommendedChannels = <FreeTvChannel>[].obs;
  final RxList<FreeTvChannel> featuredChannels = <FreeTvChannel>[].obs;
  final RxList<FreeTvChannel> favorites = <FreeTvChannel>[].obs;
  final RxList<FreeTvChannel> recentChannels = <FreeTvChannel>[].obs;

  final RxList<String> categories = <String>[].obs;
  final RxList<String> countries = <String>[].obs;
  final RxList<String> regions = <String>[].obs;
  final RxList<String> languages = <String>[].obs;

  final RxString selectedView = 'grid'.obs;
  final RxString selectedCategory = 'All Categories'.obs;
  final RxString selectedCountry = 'All Countries'.obs;
  final RxString selectedRegion = 'All Regions'.obs;
  final RxString selectedLanguage = 'All Languages'.obs;
  final RxString selectedSort = 'alphabetical'.obs;
  final RxString searchQuery = ''.obs;
  final RxBool showFavoritesOnly = false.obs;
  final RxBool showWorkingOnly = false.obs;
  final RxBool isCheckingWorking = false.obs;
  final RxInt workingCount = 0.obs;
  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;

  /// Free TV catalog mode. Defaults to the curated "recommended" catalog.
  /// Dev/admin configuration; not exposed to normal users.
  String get catalogMode => _catalogMode;
  String _catalogMode = 'recommended';
  set catalogMode(String mode) {
    _catalogMode = mode;
    _applyFiltersAndSorting();
  }

  final Rxn<FreeTvChannel> featuredChannel = Rxn<FreeTvChannel>();
  final Rxn<FreeTvChannel> activePlayingChannel = Rxn<FreeTvChannel>();
  final RxInt activeStreamIndex = 0.obs;
  final RxString playbackStatusMessage = ''.obs;

  /// Loading progress (0–100) shown while a channel resolves and buffers.
  /// Drifts up toward ~90% as loading continues and jumps to 100 on playback.
  final RxDouble loadProgress = 0.0.obs;

  /// Whether the inline player is currently resolving/opening a channel. Set as
  /// soon as a channel load begins (during stream resolution) so the player can
  /// show the loading spinner even before the engine enters a loading state.
  final RxBool isPlayerLoading = false.obs;

  final RxBool isFullscreenMode = false.obs;
  DateTime lastFullscreenEntered = DateTime.fromMillisecondsSinceEpoch(0);

  final Rxn<PlayerController> _inlinePlayerController = Rxn<PlayerController>();
  PlayerController? get inlinePlayerController => _inlinePlayerController.value;
  set inlinePlayerController(PlayerController? ctrl) =>
      _inlinePlayerController.value = ctrl;

  StreamSubscription? _favoritesSubscription;
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _playbackPositionSubscription;
  Timer? _searchDebounceTimer;
  Timer? _loadProgressTimer;
  Timer? _streamStartupWatchdogTimer;
  int _openChannelGeneration = 0;

  @override
  void onInit() {
    super.onInit();
    _initInlinePlayer();
    _loadCatalog();
    _favoritesSubscription =
        repository.watchFavorites().listen((_) => _syncFavoritesFromRepo());
  }

  @override
  void onClose() {
    _searchDebounceTimer?.cancel();
    _favoritesSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _playbackPositionSubscription?.cancel();
    _loadProgressTimer?.cancel();
    _streamStartupWatchdogTimer?.cancel();
    // Tear down the inline player engine so audio stops when the screen is
    // left. `dispose()` only clears GetX notifier lists; `stop()` + `onClose()`
    // actually stop playback and release the underlying player backend. Without
    // this, audio keeps playing after navigating away and re-entering, and a
    // stale engine from a previous controller instance can start a second
    // player that doubles the audio.
    if (inlinePlayerController != null) {
      inlinePlayerController!.stop();
      inlinePlayerController!.onClose();
    }
    super.onClose();
  }

  Future<void> _loadCatalog({bool forceRefresh = false}) async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final list = await repository.getCatalog(forceRefresh: forceRefresh);
      _allChannels.clear();
      _allChannels.addAll(list);

      _populateFilterLists();
      _syncFavoritesFromRepo();
      _loadRecentlyWatched();
      _applyFiltersAndSorting();

      if (_allChannels.isNotEmpty) {
        // Curated recommended + featured lists derived from quality tiers.
        final recommended = _recommendedAll.isNotEmpty
            ? _recommendedAll
            : _allChannels
                  .where(
                    (c) =>
                        c.qualityTier == FreeTvQualityTier.recommended ||
                        c.qualityScore >= 55,
                  )
                  .toList()
                ..sort((a, b) => b.qualityScore.compareTo(a.qualityScore));
        recommendedChannels.assignAll(recommended);

        _buildFeatured(recommended);

        // Hero fallback: a Nigerian/international news-style channel, else the
        // top-quality recommended channel.
        final heroCandidate = recommended.isNotEmpty
            ? (recommended.firstWhereOrNull(
                    (c) =>
                        c.countryCode == 'NG' ||
                        c.country.toLowerCase() == 'nigeria') ??
                recommended.first)
            : _allChannels.first;
        featuredChannel.value = heroCandidate;
      }

      final args = Get.arguments;
      MediaItem? targetChannel;
      if (args is Map) {
        if (args['channel'] is MediaItem) {
          targetChannel = args['channel'] as MediaItem;
        } else if (args['item'] is MediaItem) {
          targetChannel = args['item'] as MediaItem;
        }
      } else if (args is MediaItem) {
          targetChannel = args;
      }

      if (targetChannel != null) {
        final matched = _allChannels.firstWhereOrNull((c) => c.toMediaItem().id == targetChannel!.id);
        if (matched != null) {
          openChannel(matched, streamIndex: 0);
          if (matched.categories.isNotEmpty) {
            final targetCat = matched.categories.first.trim().toLowerCase();
            final foundCat = categories.firstWhereOrNull((c) => c.toLowerCase() == targetCat);
            if (foundCat != null) {
              setCategory(foundCat);
            }
          }
        }
      }
    } catch (e, stack) {
      _logger.error('Error loading Free Live TV catalog',
          tag: 'FreeLiveTvController', error: e, stackTrace: stack);
      errorMessage.value =
          'Unable to load Free Live TV.\nPlease check your internet connection and try again.';
    } finally {
      isLoading.value = false;
    }
  }

  void _buildRecommendedFromAll() {
    _recommendedAll.clear();
    _recommendedAll.addAll(
      _allChannels
          .where(
            (c) =>
                c.qualityTier == FreeTvQualityTier.recommended ||
                c.qualityScore >= 55,
          )
          .toList()
        ..sort((a, b) => b.qualityScore.compareTo(a.qualityScore)),
    );
  }

  void _buildFeatured(List<FreeTvChannel> recommended) {
    final featured = _recommendFeatured(recommended);
    featuredChannels.assignAll(featured);
  }

  /// Deterministically selects a small, high-value set for the Featured row.
  List<FreeTvChannel> _recommendFeatured(List<FreeTvChannel> pool) {
    if (pool.isEmpty) return const [];
    final result = <FreeTvChannel>[];
    final seen = <String>{};

    void add(FreeTvChannel ch) {
      if (seen.contains(ch.id)) return;
      seen.add(ch.id);
      result.add(ch);
    }

    // Prefer a spread of countries from the top of the recommended pool.
    final byCountry = <String, List<FreeTvChannel>>{};
    for (final ch in pool) {
      byCountry.putIfAbsent(ch.countryCode.isEmpty ? 'zz' : ch.countryCode, () => [])
          .add(ch);
    }
    for (final group in byCountry.values) {
      for (final ch in group.take(3)) {
        add(ch);
        if (result.length >= 16) break;
      }
      if (result.length >= 16) break;
    }

    // Top up from remaining recommended if the spread was sparse.
    for (final ch in pool) {
      add(ch);
      if (result.length >= 16) break;
    }

    return result.take(16).toList();
  }

  void _populateFilterLists() {
    final Set<String> catSet = {};
    final Set<String> countrySet = {};
    final Set<String> regionSet = {};
    final Set<String> langSet = {};

    for (final ch in _allChannels) {
      for (final cat in ch.categories) {
        if (cat.trim().isNotEmpty) catSet.add(cat.trim());
      }
      if (ch.country.trim().isNotEmpty) {
        countrySet.add(ch.country.trim());
      }
      if (ch.region != null && ch.region!.trim().isNotEmpty) {
        regionSet.add(ch.region!.trim());
      }
      for (final l in ch.languages) {
        if (l.trim().isNotEmpty) langSet.add(l.trim());
      }
    }

    final sortedCats = catSet.toList()..sort();
    categories.assignAll(['All Categories', ...sortedCats]);

    final sortedCountries = countrySet.toList()..sort();
    // Move selected curated countries to the top for prominent discovery.
    const priorityCountries = [
      'Nigeria',
      'South Africa',
      'United Kingdom',
      'United States',
      'France',
      'Germany',
    ];
    for (final c in priorityCountries.reversed) {
      if (sortedCountries.contains(c)) {
        sortedCountries.remove(c);
        sortedCountries.insert(0, c);
      }
    }
    countries.assignAll(['All Countries', ...sortedCountries]);

    final sortedRegions = regionSet.toList()..sort();
    regions.assignAll(['All Regions', ...sortedRegions]);

    final sortedLangs = langSet.toList()..sort();
    languages.assignAll(['All Languages', ...sortedLangs]);
  }

  void _syncFavoritesFromRepo() {
    final favIds = repository.getFavoriteIds();
    final updated = _allChannels.map((c) {
      final isFav = favIds.contains(c.id);
      return isFav != c.isFavorite ? c.copyWith(isFavorite: isFav) : c;
    }).toList();

    _allChannels.clear();
    _allChannels.addAll(updated);
    favorites.assignAll(updated.where((c) => c.isFavorite).toList());
    _buildRecommendedFromAll();
    final recommended = List.of(_recommendedAll);
    recommendedChannels.assignAll(recommended);
    _buildFeatured(recommended);
    _applyFiltersAndSorting();
  }

  Future<void> _loadRecentlyWatched() async {
    final rec = await repository.getRecentlyWatched();
    recentChannels.assignAll(rec);
  }

  bool get _hasActiveBrowseFilters =>
      selectedCategory.value != 'All Categories' ||
      selectedCountry.value != 'All Countries' ||
      selectedRegion.value != 'All Regions' ||
      selectedLanguage.value != 'All Languages' ||
      showFavoritesOnly.value ||
      searchQuery.value.trim().isNotEmpty;  void _applyFiltersAndSorting() {
    // In curated (recommended) mode, the default browse surface is the curated
    // subset. Picking an explicit filter still searches the whole valid catalog.
    final base = (!_hasActiveBrowseFilters &&
            _catalogMode == 'recommended' &&
            _recommendedAll.isNotEmpty)
        ? List.of(_recommendedAll)
        : List.of(_allChannels);
    List<FreeTvChannel> list = base;

    // 1. Category Filter
    if (selectedCategory.value != 'All Categories') {
      list = list
          .where((c) => c.categories.contains(selectedCategory.value))
          .toList();
    }

    // 2. Country Filter
    if (selectedCountry.value != 'All Countries') {
      list = list.where((c) {
        if (selectedCountry.value == 'Nigeria') {
          return c.countryCode == 'NG' ||
              c.country.toLowerCase() == 'nigeria';
        }
        return c.country == selectedCountry.value ||
            c.countryCode == selectedCountry.value;
      }).toList();
    }

    // 3. Region Filter
    if (selectedRegion.value != 'All Regions') {
      list = list
          .where((c) => c.region == selectedRegion.value)
          .toList();
    }

    // 4. Language Filter
    if (selectedLanguage.value != 'All Languages') {
      list = list
          .where((c) => c.languages.contains(selectedLanguage.value))
          .toList();
    }

    // 5. Favorites Only
    if (showFavoritesOnly.value) {
      list = list.where((c) => c.isFavorite).toList();
    }

    // 6. Working Only
    if (showWorkingOnly.value) {
      list = list.where((c) => c.isWorking == true).toList();
    }

    // 7. Search Query
    final query = searchQuery.value.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((c) {
        final matchesName = c.name.toLowerCase().contains(query);
        final matchesAlt = c.nativeName?.toLowerCase().contains(query) ?? false;
        final matchesCountry = c.country.toLowerCase().contains(query);
        final matchesCategory =
            c.categories.any((cat) => cat.toLowerCase().contains(query));
        final matchesLang =
            c.languages.any((l) => l.toLowerCase().contains(query));
        return matchesName ||
            matchesAlt ||
            matchesCountry ||
            matchesCategory ||
            matchesLang;
      }).toList();
    }

    // 8. Sorting
    switch (selectedSort.value) {
      case 'country':
        list.sort((a, b) => a.country.compareTo(b.country));
        break;
      case 'category':
        list.sort((a, b) {
          final aCat = a.categories.isNotEmpty ? a.categories.first : 'zzz';
          final bCat = b.categories.isNotEmpty ? b.categories.first : 'zzz';
          return aCat.compareTo(bCat);
        });
        break;
      case 'alphabetical':
      default:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
    }

    channels.assignAll(_allChannels);
    filteredChannels.assignAll(list);
  }

  // --- Search & Filter Setters ---

  void setSearchQuery(String q) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 250), () {
      searchQuery.value = q;
      _applyFiltersAndSorting();
    });
  }

  void setCategory(String category) {
    selectedCategory.value = category;
    _applyFiltersAndSorting();
  }

  void setCountry(String country) {
    selectedCountry.value = country;
    _applyFiltersAndSorting();
  }

  void setRegion(String region) {
    selectedRegion.value = region;
    _applyFiltersAndSorting();
  }

  void setLanguage(String language) {
    selectedLanguage.value = language;
    _applyFiltersAndSorting();
  }

  void setSort(String sort) {
    selectedSort.value = sort;
    _applyFiltersAndSorting();
  }

  void setView(String view) {
    selectedView.value = view;
  }

  void setFavoritesOnly(bool favsOnly) {
    showFavoritesOnly.value = favsOnly;
    _applyFiltersAndSorting();
  }

  /// Toggles the "Working Only" filter. Enabling it immediately shows the
  /// currently-known working channels and, when no fresh reachability snapshot
  /// exists, kicks off a background probe that refines the list as it
  /// completes.
  Future<void> setWorkingOnly(bool workingOnly) async {
    showWorkingOnly.value = workingOnly;
    if (workingOnly) {
      _applyFiltersAndSorting();
      await _ensureReachability();
    } else {
      _applyFiltersAndSorting();
    }
  }

  /// Applies cached working status to the known-working set, polling the cache
  /// first so the UI responds instantly, then re-probing in the background if
  /// the snapshot is stale or empty.
  Future<void> _ensureReachability() async {
    try {
      workingCount.value = _countWorking(_allChannels);

      final cachedWorking = await repository.getWorkingCatalog();
      if (cachedWorking.isNotEmpty) {
        _applyWorkingStatus(cachedWorking);
        workingCount.value = _countWorking(_allChannels);
        _applyFiltersAndSorting();
      }
    } catch (e) {
      _logger.warning(
        'Failed to load cached working channels: $e',
        tag: 'FreeLiveTvController',
      );
    }

    // Probe the curated set in the background (bounded) to keep the catalog
    // reachable/up to date. Only the recommended tier is probed to bound cost.
    _refreshReachability();
  }

  Future<void> _refreshReachability() async {
    if (isCheckingWorking.value) return;
    isCheckingWorking.value = true;
    try {
      final targets = _recommendedAll.isNotEmpty
          ? _recommendedAll
          : _allChannels.where(
              (c) =>
                  c.qualityTier == FreeTvQualityTier.recommended ||
                  c.qualityScore >= 55,
            ).toList();

      final probed = await repository.refreshWorkingStatus(
        targets,
        maxChannels: 1500,
      );
      _applyWorkingStatus(probed);

      _populateWorkingCount();
      _applyFiltersAndSorting();
    } catch (e) {
      _logger.error('Reachability probe failed',
          tag: 'FreeLiveTvController', error: e);
    } finally {
      isCheckingWorking.value = false;
    }
  }

  void _applyWorkingStatus(List<FreeTvChannel> probed) {
    if (probed.isEmpty) return;
    final statusById = {
      for (final c in probed) c.id: c.isWorking,
    };
    final updated = _allChannels.map((c) {
      final status = statusById[c.id];
      if (status == null || status == c.isWorking) return c;
      return c.copyWith(isWorking: status);
    }).toList();
    _allChannels.clear();
    _allChannels.addAll(updated);
    _buildRecommendedFromAll();
    final recommended = List.of(_recommendedAll);
    recommendedChannels.assignAll(recommended);
    _buildFeatured(recommended);
  }

  void _populateWorkingCount() {
    workingCount.value = _countWorking(_allChannels);
  }

  int _countWorking(List<FreeTvChannel> channels) =>
      channels.where((c) => c.isWorking == true).length;

  void clearFilters() {
    searchQuery.value = '';
    selectedCategory.value = 'All Categories';
    selectedCountry.value = 'All Countries';
    selectedRegion.value = 'All Regions';
    selectedLanguage.value = 'All Languages';
    selectedSort.value = 'alphabetical';
    showFavoritesOnly.value = false;
    showWorkingOnly.value = false;
    _applyFiltersAndSorting();
  }

  @override
  Future<void> refresh() async {
    await _loadCatalog(forceRefresh: true);
  }

  Future<void> toggleFavorite(FreeTvChannel channel) async {
    await repository.toggleFavorite(channel.id);
    _syncFavoritesFromRepo();
  }

  // --- Inline Embedded Player Management ---

  void _initInlinePlayer() {
    if (inlinePlayerController != null) return;
    if (!Get.isRegistered<StreamRepository>()) return;

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
      }
    }

    final playerCtrl = PlayerController(
      engineKind: chosenEngine,
      streamRepository: Get.find<StreamRepository>(),
    );
    playerCtrl.onInit();
    inlinePlayerController = playerCtrl;

    _playerStateSubscription?.cancel();
    _playerStateSubscription = playerCtrl
        .playbackController.engine.stateRx
        .listen((state) {
      if (state == PlaybackState.error) {
        _streamStartupWatchdogTimer?.cancel();
        _playbackPositionSubscription?.cancel();
        _stopPlayerLoading(complete: false);
        _handlePlaybackError();
      } else if (state == PlaybackState.playing) {
        _streamStartupWatchdogTimer?.cancel();
        _waitForPlaybackToActuallyRender(playerCtrl);
      } else if (state == PlaybackState.loading ||
          state == PlaybackState.buffering) {
        _startPlayerProgress();
      } else if (state.isStoppedLike) {
        _streamStartupWatchdogTimer?.cancel();
        _playbackPositionSubscription?.cancel();
        // Do not clear the loading indicator if we are in the middle of opening a channel
        if (!isPlayerLoading.value) {
          _stopPlayerLoading(complete: false);
        }
      }
    });
  }

  void _waitForPlaybackToActuallyRender(PlayerController playerCtrl) {
    _playbackPositionSubscription?.cancel();

    // If the player is already actively decoding and has rendered past 0, complete immediately
    final currentPos = playerCtrl.playbackController.engine.positionRx.value;
    if (currentPos > Duration.zero) {
      _stopPlayerLoading(complete: true);
      playbackStatusMessage.value = '';
      return;
    }

    // Keep the loading spinner active until the first video frame/position advances.
    // Use a bounded fallback timer (2.5s) in case position updates are slow or stream is audio-only.
    Timer? fallbackTimer;
    fallbackTimer = Timer(const Duration(milliseconds: 2500), () {
      _playbackPositionSubscription?.cancel();
      _stopPlayerLoading(complete: true);
      playbackStatusMessage.value = '';
    });

    _playbackPositionSubscription = playerCtrl
        .playbackController.engine.positionRx
        .listen((pos) {
      if (pos > Duration.zero) {
        fallbackTimer?.cancel();
        _playbackPositionSubscription?.cancel();
        _stopPlayerLoading(complete: true);
        playbackStatusMessage.value = '';
      }
    });
  }

  void _startPlayerLoading() {
    isPlayerLoading.value = true;
    _startPlayerProgress();
  }

  /// Animates [loadProgress] from its current value toward ~90% so the user
  /// gets a smooth, honest-feeling indicator while a channel resolves and
  /// buffers. Live streams rarely expose a reliable buffered fraction, so the
  /// percentage here is a staged estimate: it approaches but never reaches 100
  /// until playback actually starts.
  void _startPlayerProgress() {
    _loadProgressTimer?.cancel();
    if (loadProgress.value <= 0) loadProgress.value = 8;
    _loadProgressTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      final current = loadProgress.value;
      final next = current < 70
          ? current + 4
          : current < 90
              ? current + 1
              : 90;
      loadProgress.value = next.clamp(0, 100).toDouble();
      if (next >= 90) {
        _loadProgressTimer?.cancel();
      }
    });
  }

  void _stopPlayerLoading({required bool complete}) {
    _loadProgressTimer?.cancel();
    isPlayerLoading.value = false;
    loadProgress.value = complete ? 100 : 0;
  }

  /// Plays the channel with automatic multi-stream fallback.
  Future<void> openChannel(FreeTvChannel channel, {int streamIndex = 0}) async {
    if (channel.streamUrls.isEmpty) {
      playbackStatusMessage.value = 'No playable stream found for this channel.';
      return;
    }

    final currentGen = ++_openChannelGeneration;
    _streamStartupWatchdogTimer?.cancel();
    _playbackPositionSubscription?.cancel();

    _initInlinePlayer();
    // Stop any currently-playing stream BEFORE activating the new channel.
    // Otherwise a failing new stream would surface an error overlay on top of
    // the previous channel's still-active playback, or the previous stream's stop
    // event would clear the new channel's loading indicator.
    if (inlinePlayerController != null) {
      await inlinePlayerController?.stop();
    }
    if (currentGen != _openChannelGeneration) return;

    // Update active channel and kick off loading spinner immediately
    activePlayingChannel.value = channel;
    activeStreamIndex.value = streamIndex;
    playbackStatusMessage.value = '';
    _stopPlayerLoading(complete: false);
    _startPlayerLoading();

    // Record to recently watched in background without blocking player
    unawaited(repository.recordWatch(channel).then((_) {
      if (currentGen == _openChannelGeneration) {
        _loadRecentlyWatched();
      }
    }));

    final currentStreamUrl = channel.streamUrls[streamIndex];
    final mediaItem = channel.toMediaItem().copyWith(
      metadata: {
        ...channel.toMediaItem().metadata,
        'streamUrl': currentStreamUrl,
        'isLive': true,
      },
    );

    _logger.info(
      'Playing Free TV Channel "${channel.name}" (Stream ${streamIndex + 1}/${channel.streamUrls.length}): $currentStreamUrl',
      tag: 'FreeLiveTvController',
    );

    // If backup streams exist, start a watchdog to fail over fast if the stream stalls/hangs
    if (channel.streamUrls.length > 1 && streamIndex < channel.streamUrls.length - 1) {
      _streamStartupWatchdogTimer = Timer(const Duration(seconds: 7), () {
        if (currentGen == _openChannelGeneration &&
            isPlayerLoading.value &&
            activePlayingChannel.value?.id == channel.id) {
          _logger.warning(
            'Stream ${streamIndex + 1} for "${channel.name}" exceeded startup threshold (7s). Failing over to next stream...',
            tag: 'FreeLiveTvController',
          );
          _handlePlaybackError();
        }
      });
    }

    inlinePlayerController?.setChannelList([mediaItem], currentId: mediaItem.id);
  }

  /// Automatically attempts the next stream candidate if the active stream fails.
  void _handlePlaybackError() {
    final active = activePlayingChannel.value;
    if (active == null) return;

    final nextIndex = activeStreamIndex.value + 1;
    if (nextIndex < active.streamUrls.length) {
      _logger.warning(
        'Stream $nextIndex failed for "${active.name}". Trying backup stream ${nextIndex + 1}...',
        tag: 'FreeLiveTvController',
      );
      playbackStatusMessage.value =
          'Stream unavailable, attempting fallback (${nextIndex + 1}/${active.streamUrls.length})...';
      openChannel(active, streamIndex: nextIndex);
    } else {
      _logger.error(
        'All streams failed for "${active.name}".',
        tag: 'FreeLiveTvController',
      );
      playbackStatusMessage.value =
          'Unable to play this channel right now.\nPlease try again later or select another channel.';
    }
  }

  void stopInlinePlayer() {
    _openChannelGeneration++;
    _streamStartupWatchdogTimer?.cancel();
    _playbackPositionSubscription?.cancel();
    inlinePlayerController?.stop();
    activePlayingChannel.value = null;
    playbackStatusMessage.value = '';
    _stopPlayerLoading(complete: false);
  }

  void enterFullscreen() {
    isFullscreenMode.value = true;
    lastFullscreenEntered = DateTime.now();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  void exitFullscreen() {
    isFullscreenMode.value = false;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    if (!PlatformHelper.isTV) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }
}
