import 'dart:async';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../core/guards/subscription_guard.dart';
import '../../core/logging/logging_service.dart';
import '../repositories/subscription_repository.dart';
import 'database_service.dart';

/// Service responsible for managing the user's "10 Free Channel Pass" slots
/// on the Free Live TV catalog.
///
/// Behavior:
/// - 30-Day VIP Trial / Active Subscription: All channels unlocked (gating inactive).
/// - Free Tier (Trial expired or unsubscribed): The user can hand-pick up to 10 channels
///   to watch 100% free forever.
/// - Attempting to watch an 11th channel prompts the user to either:
///   1. Upgrade to VIP (unlimited access)
///   2. Swap out one of their 10 picked channels.
class FreeTvSlotService extends GetxService {
  static const int maxSlots = 10;
  static const String _kSelectedChannelIdsKey = 'selected_channel_ids';

  final DatabaseService? _databaseService;
  final LoggingService _logger;

  FreeTvSlotService({
    DatabaseService? databaseService,
    LoggingService? logger,
  })  : _databaseService = databaseService,
        _logger = logger ??
            (Get.isRegistered<LoggingService>()
                ? Get.find<LoggingService>()
                : LoggingService());

  final RxList<String> selectedChannelIds = <String>[].obs;
  final RxBool isVipActive = false.obs;

  /// Test flag allowing developers/testers to simulate the Free Tier (trial expired)
  /// without waiting 30 days.
  final RxBool simulateFreeTier = false.obs;

  StreamSubscription? _subscriptionSub;

  Box? _getBox() {
    try {
      if (_databaseService != null && Hive.isBoxOpen(AppConstants.boxFreeTvSlots)) {
        return _databaseService.freeTvSlotsBox;
      }
      if (Get.isRegistered<DatabaseService>()) {
        final db = Get.find<DatabaseService>();
        if (Hive.isBoxOpen(AppConstants.boxFreeTvSlots)) {
          return db.freeTvSlotsBox;
        }
      }
      if (Hive.isBoxOpen(AppConstants.boxFreeTvSlots)) {
        return Hive.box(AppConstants.boxFreeTvSlots);
      }
    } catch (e) {
      _logger.warning('Failed to get freeTvSlotsBox: $e', tag: 'FreeTvSlotService');
    }
    return null;
  }

  @override
  void onInit() {
    super.onInit();
    _loadFromBox();
    _initSubscriptionWatcher();
  }

  @override
  void onClose() {
    _subscriptionSub?.cancel();
    super.onClose();
  }

  void _initSubscriptionWatcher() {
    _updateVipStatus();
    if (Get.isRegistered<SubscriptionRepository>()) {
      _subscriptionSub = Get.find<SubscriptionRepository>()
          .watchSubscription()
          .listen((_) => _updateVipStatus());
    }
  }

  void _updateVipStatus() {
    if (SubscriptionGuard.isSubscribed) {
      isVipActive.value = true;
    }
  }

  Future<void> _loadFromBox() async {
    try {
      Box? box = _getBox();
      if (box == null) {
        if (!Hive.isBoxOpen(AppConstants.boxFreeTvSlots)) {
          box = await Hive.openBox(AppConstants.boxFreeTvSlots);
        } else {
          box = Hive.box(AppConstants.boxFreeTvSlots);
        }
      }

      final rawList = box.get(_kSelectedChannelIdsKey);
      if (rawList != null && rawList is List) {
        final ids = List<String>.from(rawList);
        selectedChannelIds.assignAll(ids.take(maxSlots));
      }
      _updateVipStatus();
      _logger.info(
        'Loaded ${selectedChannelIds.length}/$maxSlots free TV channel slots. VIP: ${isVipActive.value}',
        tag: 'FreeTvSlotService',
      );
    } catch (e) {
      _logger.error('Error loading free TV slots from Hive: $e', tag: 'FreeTvSlotService');
    }
  }

  Future<void> _saveToBox() async {
    try {
      Box? box = _getBox();
      if (box == null) {
        if (!Hive.isBoxOpen(AppConstants.boxFreeTvSlots)) {
          box = await Hive.openBox(AppConstants.boxFreeTvSlots);
        } else {
          box = Hive.box(AppConstants.boxFreeTvSlots);
        }
      }
      await box.put(_kSelectedChannelIdsKey, selectedChannelIds.toList());
      _logger.info(
        'Saved ${selectedChannelIds.length}/$maxSlots free TV channel slots to Hive.',
        tag: 'FreeTvSlotService',
      );
    } catch (e) {
      _logger.error('Error saving free TV slots to Hive: $e', tag: 'FreeTvSlotService');
    }
  }

  /// Whether VIP/trial is active and all channels are unrestricted.
  bool get isVip {
    if (simulateFreeTier.value) return false;
    return isVipActive.value || SubscriptionGuard.isSubscribed;
  }

  /// Whether the 10-channel gating restriction is active (i.e. Free tier / trial expired).
  bool get isGatingActive => !isVip;

  /// Number of free channel slots currently occupied.
  int get usedSlots => selectedChannelIds.length;

  /// Number of remaining free channel slots available for selection.
  int get remainingSlots => (maxSlots - selectedChannelIds.length).clamp(0, maxSlots);

  /// Whether all 10 free channel slots are filled.
  bool get isFull => selectedChannelIds.length >= maxSlots;

  /// Whether a specific channel is selected in the user's 10 free slots.
  bool isChannelSelected(String channelId) {
    return selectedChannelIds.contains(channelId);
  }

  /// Whether a channel is unlocked for playback.
  /// Always returns true for VIP/Trial users.
  /// For Free users, returns true only if the channel is in their 10 slots.
  bool isChannelUnlocked(String channelId) {
    if (isVip) return true;
    return selectedChannelIds.contains(channelId);
  }

  /// Adds a channel to the free pass slots.
  /// Returns `true` if added or already present.
  /// Returns `false` if the 10 slots are already full.
  Future<bool> addChannel(String channelId) async {
    if (channelId.isEmpty) return false;
    if (selectedChannelIds.contains(channelId)) return true;
    if (selectedChannelIds.length >= maxSlots) return false;

    selectedChannelIds.add(channelId);
    await _saveToBox();
    return true;
  }

  /// Removes a channel from the free pass slots, freeing up a slot.
  Future<void> removeChannel(String channelId) async {
    if (selectedChannelIds.remove(channelId)) {
      await _saveToBox();
    }
  }

  /// Swaps an existing channel in the free pass with a new one.
  Future<bool> swapChannel({
    required String oldChannelId,
    required String newChannelId,
  }) async {
    if (newChannelId.isEmpty) return false;
    if (selectedChannelIds.contains(newChannelId)) return true;

    final index = selectedChannelIds.indexOf(oldChannelId);
    if (index >= 0) {
      selectedChannelIds[index] = newChannelId;
      await _saveToBox();
      return true;
    } else {
      // If old not found, add if slots remain
      return addChannel(newChannelId);
    }
  }

  /// Clears all selected channels.
  Future<void> clearAll() async {
    selectedChannelIds.clear();
    await _saveToBox();
  }
}
