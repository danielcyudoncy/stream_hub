import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
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

  final RxList<FreeTvChannel> channels = <FreeTvChannel>[].obs;
  final RxList<FreeTvChannel> filteredChannels = <FreeTvChannel>[].obs;
  final RxList<FreeTvChannel> favorites = <FreeTvChannel>[].obs;
  final RxList<FreeTvChannel> recentChannels = <FreeTvChannel>[].obs;

  final RxList<String> categories = <String>[].obs;
  final RxList<String> countries = <String>[].obs;
  final RxList<String> languages = <String>[].obs;

  final RxString selectedView = 'grid'.obs;
  final RxString selectedCategory = 'All Categories'.obs;
  final RxString selectedCountry = 'All Countries'.obs;
  final RxString selectedLanguage = 'All Languages'.obs;
  final RxString selectedSort = 'alphabetical'.obs;
  final RxString searchQuery = ''.obs;
  final RxBool showFavoritesOnly = false.obs;
  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;

  final Rxn<FreeTvChannel> featuredChannel = Rxn<FreeTvChannel>();
  final Rxn<FreeTvChannel> activePlayingChannel = Rxn<FreeTvChannel>();
  final RxInt activeStreamIndex = 0.obs;
  final RxString playbackStatusMessage = ''.obs;

  final RxBool isFullscreenMode = false.obs;
  DateTime lastFullscreenEntered = DateTime.fromMillisecondsSinceEpoch(0);

  final GlobalKey embeddedPlayerKey =
      GlobalKey(debugLabel: 'free_tv_embedded_player');
  PlayerController? inlinePlayerController;
  StreamSubscription? _favoritesSubscription;
  StreamSubscription? _playerStateSubscription;
  Timer? _searchDebounceTimer;

  @override
  void onInit() {
    super.onInit();
    _loadCatalog();
    _favoritesSubscription =
        repository.watchFavorites().listen((_) => _syncFavoritesFromRepo());
  }

  @override
  void onClose() {
    _searchDebounceTimer?.cancel();
    _favoritesSubscription?.cancel();
    _playerStateSubscription?.cancel();
    inlinePlayerController?.dispose();
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
        // Find a featured channel (e.g. Nigerian or international news/popular channel)
        final nigerianChannel = _allChannels.firstWhereOrNull(
          (c) => c.countryCode == 'NG' || c.country.toLowerCase() == 'nigeria',
        );
        featuredChannel.value = nigerianChannel ?? _allChannels.first;
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

  void _populateFilterLists() {
    final Set<String> catSet = {};
    final Set<String> countrySet = {};
    final Set<String> langSet = {};

    for (final ch in _allChannels) {
      for (final cat in ch.categories) {
        if (cat.trim().isNotEmpty) catSet.add(cat.trim());
      }
      if (ch.country.trim().isNotEmpty) {
        countrySet.add(ch.country.trim());
      }
      for (final l in ch.languages) {
        if (l.trim().isNotEmpty) langSet.add(l.trim());
      }
    }

    final sortedCats = catSet.toList()..sort();
    categories.assignAll(['All Categories', ...sortedCats]);

    final sortedCountries = countrySet.toList()..sort();
    // Move Nigeria to the top of the country list for prominent Nigerian discovery
    if (sortedCountries.contains('Nigeria')) {
      sortedCountries.remove('Nigeria');
      sortedCountries.insert(0, 'Nigeria');
    }
    countries.assignAll(['All Countries', ...sortedCountries]);

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
    _applyFiltersAndSorting();
  }

  Future<void> _loadRecentlyWatched() async {
    final rec = await repository.getRecentlyWatched();
    recentChannels.assignAll(rec);
  }

  void _applyFiltersAndSorting() {
    List<FreeTvChannel> list = List.of(_allChannels);

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

    // 3. Language Filter
    if (selectedLanguage.value != 'All Languages') {
      list = list
          .where((c) => c.languages.contains(selectedLanguage.value))
          .toList();
    }

    // 4. Favorites Only
    if (showFavoritesOnly.value) {
      list = list.where((c) => c.isFavorite).toList();
    }

    // 5. Search Query
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

    // 6. Sorting
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

  void clearFilters() {
    searchQuery.value = '';
    selectedCategory.value = 'All Categories';
    selectedCountry.value = 'All Countries';
    selectedLanguage.value = 'All Languages';
    selectedSort.value = 'alphabetical';
    showFavoritesOnly.value = false;
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
        _handlePlaybackError();
      } else if (state == PlaybackState.playing) {
        playbackStatusMessage.value = '';
      }
    });
  }

  /// Plays the channel with automatic multi-stream fallback.
  Future<void> openChannel(FreeTvChannel channel, {int streamIndex = 0}) async {
    if (channel.streamUrls.isEmpty) {
      playbackStatusMessage.value = 'No playable stream found for this channel.';
      return;
    }

    _initInlinePlayer();
    activePlayingChannel.value = channel;
    activeStreamIndex.value = streamIndex;
    playbackStatusMessage.value = '';

    // Record to recently watched
    repository.recordWatch(channel);
    _loadRecentlyWatched();

    final currentStreamUrl = channel.streamUrls[streamIndex];
    final mediaItem = channel.toMediaItem().copyWith(
      metadata: {
        ...channel.toMediaItem().metadata,
        'streamUrl': currentStreamUrl,
      },
    );

    _logger.info(
      'Playing Free TV Channel "${channel.name}" (Stream ${streamIndex + 1}/${channel.streamUrls.length}): $currentStreamUrl',
      tag: 'FreeLiveTvController',
    );

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
    inlinePlayerController?.stop();
    activePlayingChannel.value = null;
    playbackStatusMessage.value = '';
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
