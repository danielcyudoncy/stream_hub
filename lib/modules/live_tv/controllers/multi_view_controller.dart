import 'dart:async';
import 'package:get/get.dart';
import '../../../core/iptv/models/player_negotiation.dart';
import '../../../core/media/enums/media_type.dart';
import '../../../core/media/enums/playback_state.dart';
import '../../../core/media/enums/playback_engine_preference.dart';
import '../../../core/media/media_engine.dart';
import '../../../core/media/media_library.dart';
import '../../../core/media/player/exo_player_surface_view_adapter.dart';
import '../../../core/media/player/ijk_player_adapter.dart';
import '../../../core/media/player/vlc_player_adapter.dart';
import '../../../core/media/stream_resolver.dart';
import '../../../core/media/stream_resolvers/m3u_stream_resolver.dart';
import '../../../data/models/media_item.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../player/controllers/player_controller.dart';
import '../../settings/settings_controller.dart';
import '../models/multi_view_layout_mode.dart';

class MultiViewController extends GetxController {
  final CatalogRepository catalogRepository;
  final MediaEngine mediaEngine;
  final MediaLibrary mediaLibrary;
  final StreamResolver streamResolver;

  MultiViewController({
    required this.catalogRepository,
    required this.mediaEngine,
    required this.mediaLibrary,
    StreamResolver? streamResolver,
  }) : streamResolver = streamResolver ?? M3UStreamResolver();

  final Rx<MultiViewLayoutMode> layoutMode = MultiViewLayoutMode.quad.obs;
  final RxInt activeAudioSlot = 0.obs;
  final List<Rxn<MediaItem>> slots = List.generate(4, (_) => Rxn<MediaItem>());
  final List<PlayerController?> slotControllers = List.generate(4, (_) => null);
  final RxList<MediaItem> allChannels = <MediaItem>[].obs;
  final RxList<MediaItem> allCategories = <MediaItem>[].obs;
  final RxList<String> categories = <String>['All Channels'].obs;
  final RxList<String> providers = <String>[].obs;
  final RxBool isLoadingChannels = true.obs;

  @override
  void onInit() {
    super.onInit();
    _loadChannels();
    // Pre-populate slot 0 if passed via Get.arguments
    if (Get.arguments is MediaItem) {
      final initialChannel = Get.arguments as MediaItem;
      setChannelForSlot(0, initialChannel);
    }
  }

  Future<void> _loadChannels() async {
    try {
      isLoadingChannels.value = true;
      final channels = await catalogRepository.getByType(MediaType.channel);
      final rawCategories = await catalogRepository.getByType(MediaType.collection);
      allChannels.assignAll(channels);
      allCategories.assignAll(rawCategories);

      final categorySet = <String>{};
      final providerSet = <String>{};

      for (final ch in channels) {
        for (final genre in ch.genres) {
          if (genre.trim().isNotEmpty) categorySet.add(genre.trim());
        }
        final catCandidates = [
          ch.metadata['category']?.toString(),
          ch.metadata['category_name']?.toString(),
          ch.metadata['genre']?.toString(),
          ch.metadata['group']?.toString(),
          ch.metadata['group_title']?.toString(),
          ch.metadata['group-title']?.toString(),
        ];
        for (final cat in catCandidates) {
          if (cat != null && cat.trim().isNotEmpty) {
            categorySet.add(cat.trim());
          }
        }
        if (ch.providerId.trim().isNotEmpty) {
          providerSet.add(ch.providerId.trim());
        }
      }

      for (final cat in rawCategories) {
        final isLive = cat.metadata['type'] == 'live' || cat.metadata['type'] == null;
        if (isLive && cat.title.trim().isNotEmpty) {
          categorySet.add(cat.title.trim());
        }
        if (cat.providerId.trim().isNotEmpty) {
          providerSet.add(cat.providerId.trim());
        }
      }

      final sortedCategories = categorySet.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      categories.assignAll(['All Channels', ...sortedCategories]);
      providers.assignAll(providerSet.toList()..sort());
    } catch (e) {
      // Ignore
    } finally {
      isLoadingChannels.value = false;
    }
  }

  bool channelMatchesCategory(MediaItem channel, String selectedCategory) {
    if (selectedCategory == 'All Channels') return true;

    for (final genre in channel.genres) {
      if (genre.trim().toLowerCase() == selectedCategory.trim().toLowerCase()) {
        return true;
      }
    }

    final candidates = [
      channel.metadata['category']?.toString(),
      channel.metadata['category_name']?.toString(),
      channel.metadata['genre']?.toString(),
      channel.metadata['group']?.toString(),
      channel.metadata['group_title']?.toString(),
      channel.metadata['group-title']?.toString(),
    ];

    for (final cand in candidates) {
      if (cand != null && cand.trim().toLowerCase() == selectedCategory.trim().toLowerCase()) {
        return true;
      }
    }

    final categoryId = channel.metadata['category_id']?.toString() ??
        channel.metadata['category_ids']?.toString();
    if (categoryId != null && categoryId.isNotEmpty) {
      for (final cat in allCategories) {
        if ((cat.id == categoryId || cat.metadata['category_id']?.toString() == categoryId) &&
            cat.title.trim().toLowerCase() == selectedCategory.trim().toLowerCase()) {
          return true;
        }
      }
    }

    return false;
  }

  List<String> getCategoriesForProvider(String providerId) {
    if (providerId.isEmpty) return categories;

    final catSet = <String>{};
    for (final ch in allChannels) {
      if (ch.providerId == providerId ||
          ch.providerType.displayName.toLowerCase() == providerId.toLowerCase() ||
          ch.providerType.name.toLowerCase() == providerId.toLowerCase()) {
        for (final genre in ch.genres) {
          if (genre.trim().isNotEmpty) catSet.add(genre.trim());
        }
        final catCandidates = [
          ch.metadata['category']?.toString(),
          ch.metadata['category_name']?.toString(),
          ch.metadata['genre']?.toString(),
          ch.metadata['group']?.toString(),
          ch.metadata['group_title']?.toString(),
          ch.metadata['group-title']?.toString(),
        ];
        for (final cat in catCandidates) {
          if (cat != null && cat.trim().isNotEmpty) {
            catSet.add(cat.trim());
          }
        }
      }
    }

    for (final cat in allCategories) {
      final isLive = cat.metadata['type'] == 'live' || cat.metadata['type'] == null;
      if (isLive &&
          (cat.providerId == providerId ||
              cat.providerType.displayName.toLowerCase() == providerId.toLowerCase() ||
              cat.providerType.name.toLowerCase() == providerId.toLowerCase())) {
        if (cat.title.trim().isNotEmpty) {
          catSet.add(cat.title.trim());
        }
      }
    }

    final sorted = catSet.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ['All Channels', ...sorted];
  }

  String? getChannelCategoryName(MediaItem ch) {
    if (ch.genres.isNotEmpty) return ch.genres.first;
    final metaCat = ch.metadata['category_name']?.toString() ??
        ch.metadata['category']?.toString() ??
        ch.metadata['genre']?.toString() ??
        ch.metadata['group_title']?.toString() ??
        ch.metadata['group-title']?.toString() ??
        ch.metadata['group']?.toString();
    if (metaCat != null && metaCat.isNotEmpty) return metaCat;
    final catId = ch.metadata['category_id']?.toString() ??
        ch.metadata['category_ids']?.toString();
    if (catId != null && catId.isNotEmpty) {
      for (final cat in allCategories) {
        if (cat.id == catId || cat.metadata['category_id']?.toString() == catId) {
          return cat.title;
        }
      }
    }
    return null;
  }

  Future<void> setChannelForSlot(int slotIndex, MediaItem channel) async {
    if (slotIndex < 0 || slotIndex >= 4) return;

    // Stop existing player in slot if any
    final existingCtrl = slotControllers[slotIndex];
    if (existingCtrl != null) {
      try {
        existingCtrl.stop();
      } catch (_) {}
    }

    slots[slotIndex].value = channel;

    // Create a new dedicated player controller for this slot
    final newCtrl = _createSlotPlayerController(slotIndex);
    slotControllers[slotIndex] = newCtrl;

    // Make the new channel the active audio slot
    setActiveAudioSlot(slotIndex);

    await newCtrl.playMediaItem(channel);

    // Re-assert audio focus across all slots now that playback session and views have initialized
    setActiveAudioSlot(activeAudioSlot.value);
  }

  void clearSlot(int slotIndex) {
    if (slotIndex < 0 || slotIndex >= 4) return;
    final ctrl = slotControllers[slotIndex];
    if (ctrl != null) {
      try {
        ctrl.stop();
      } catch (_) {}
      slotControllers[slotIndex] = null;
    }
    slots[slotIndex].value = null;

    // If active slot was cleared, fallback to another active slot
    if (activeAudioSlot.value == slotIndex) {
      for (int i = 0; i < 4; i++) {
        if (slots[i].value != null && slotControllers[i] != null) {
          setActiveAudioSlot(i);
          break;
        }
      }
    }
  }

  void setActiveAudioSlot(int slotIndex) {
    if (slotIndex < 0 || slotIndex >= 4) return;
    activeAudioSlot.value = slotIndex;

    for (int i = 0; i < 4; i++) {
      final ctrl = slotControllers[i];
      if (ctrl != null) {
        if (i == slotIndex) {
          ctrl.setMuted(false);
          ctrl.setVolume(1.0);
          try {
            if (ctrl.state == PlaybackState.paused) {
              ctrl.resume();
            }
          } catch (_) {}
        } else {
          ctrl.setVolume(0.0);
          ctrl.setMuted(true);
        }
      }
    }
  }

  void setLayoutMode(MultiViewLayoutMode mode) {
    layoutMode.value = mode;
    final maxAllowed = mode.slotCount;
    // Clear unused slots beyond layout count
    for (int i = maxAllowed; i < 4; i++) {
      if (slots[i].value != null) {
        clearSlot(i);
      }
    }
    // Adjust active audio slot if out of bounds
    if (activeAudioSlot.value >= maxAllowed) {
      setActiveAudioSlot(0);
    }
  }

  PlayerController _createSlotPlayerController(int slotIndex) {
    PlaybackEngineKind chosenEngine = PlaybackEngineKind.mediaKit;
    if (Get.isRegistered<SettingsController>()) {
      final pref = Get.find<SettingsController>().preferredPlayer.value;
      if (pref == PlaybackEnginePreference.exoPlayer && ExoPlayerSurfaceViewAdapter.isSupported) {
        chosenEngine = PlaybackEngineKind.exoPlayer;
      } else if (pref == PlaybackEnginePreference.vlc && VlcPlayerAdapter.isSupported) {
        chosenEngine = PlaybackEngineKind.vlc;
      } else if (pref == PlaybackEnginePreference.ijk && IjkPlayerAdapter.isSupported) {
        chosenEngine = PlaybackEngineKind.ijk;
      } else if (ExoPlayerSurfaceViewAdapter.isSupported) {
        chosenEngine = PlaybackEngineKind.exoPlayer;
      }
    } else if (ExoPlayerSurfaceViewAdapter.isSupported) {
      chosenEngine = PlaybackEngineKind.exoPlayer;
    }

    final player = PlayerController(
      engineKind: chosenEngine,
      catalogRepository: catalogRepository,
    );
    player.onInit();
    return player;
  }

  @override
  void onClose() {
    for (int i = 0; i < 4; i++) {
      final ctrl = slotControllers[i];
      if (ctrl != null) {
        try {
          ctrl.stop();
          ctrl.dispose();
        } catch (_) {}
      }
    }
    super.onClose();
  }
}
