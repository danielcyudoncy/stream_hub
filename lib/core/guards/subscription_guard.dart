import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/repositories/subscription_repository.dart';
import '../routes/app_routes.dart';

/// Supported features in StreamHub Pro with entitlement gating.
enum EntitledFeature {
  /// Open public TV channels (IPTV-org) - ALWAYS free per ARCHITECTURE.md
  freeLiveTv,

  /// Adding and syncing custom IPTV sources (M3U, Xtream, Stalker)
  customIptvProviders,

  /// Playing streams originating from user-added providers
  providerStreamPlayback,

  /// Downloading movies, series, or VOD for offline viewing
  offlineDownloads,

  /// Multi-screen simultaneous live viewing
  multiView,

  /// Cloud synchronization across TV and mobile devices
  crossDeviceCloudSync,
}

/// Centralized entitlement check and feature guard.
///
/// Ensures compliance with StreamHub Pro architectural invariants:
/// - Free Live TV remains 100% free and subscription-independent.
/// - Custom IPTV providers and premium features require an active subscription.
class SubscriptionGuard {
  static SubscriptionRepository? get _repo {
    if (Get.isRegistered<SubscriptionRepository>()) {
      return Get.find<SubscriptionRepository>();
    }
    return null;
  }

  /// Whether the user has an active premium subscription.
  static bool get isSubscribed => _repo?.isSubscribed ?? false;

  /// Checks if a feature is unlocked for the current user.
  static bool canAccess(EntitledFeature feature) {
    switch (feature) {
      case EntitledFeature.freeLiveTv:
        // Core Invariant: Free Live TV requires NO provider and NO subscription.
        return true;
      case EntitledFeature.customIptvProviders:
      case EntitledFeature.providerStreamPlayback:
      case EntitledFeature.offlineDownloads:
      case EntitledFeature.multiView:
      case EntitledFeature.crossDeviceCloudSync:
        return isSubscribed;
    }
  }

  /// Protects a feature action: executes [onAllowed] if entitled, or prompts the
  /// user to subscribe if un-entitled.
  static Future<void> protect({
    required BuildContext context,
    required EntitledFeature feature,
    required VoidCallback onAllowed,
    String? featureName,
  }) async {
    if (canAccess(feature)) {
      onAllowed();
      return;
    }

    final allowed = await promptPaywall(
      context: context,
      featureName: featureName ?? _defaultFeatureName(feature),
    );

    if (allowed) {
      onAllowed();
    }
  }

  /// Shows the paywall modal/bottom-sheet or redirects to the subscription screen.
  static Future<bool> promptPaywall({
    required BuildContext context,
    String? featureName,
  }) async {
    await Get.toNamed(AppRoutes.subscription);
    return isSubscribed;
  }

  static String _defaultFeatureName(EntitledFeature feature) {
    switch (feature) {
      case EntitledFeature.freeLiveTv:
        return 'Free Live TV';
      case EntitledFeature.customIptvProviders:
        return 'Custom IPTV Providers';
      case EntitledFeature.providerStreamPlayback:
        return 'Provider Playback';
      case EntitledFeature.offlineDownloads:
        return 'Offline Downloads';
      case EntitledFeature.multiView:
        return 'Multi-View';
      case EntitledFeature.crossDeviceCloudSync:
        return 'Cloud Sync';
    }
  }
}
