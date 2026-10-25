import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/iptv/debug/debug_mode_service.dart';
import 'package:stream_hub/core/iptv/iptv_core.dart';
import 'package:stream_hub/data/repositories/subscription_repository.dart';
import 'package:stream_hub/shared/dialogs/owner_pin_dialog.dart';

class DeveloperController extends GetxController {
  final IptvCore core;

  DeveloperController(this.core);

  DebugModeService get debugMode => core.debugMode;

  bool get isDebugEnabled => debugMode.isEnabled;

  final RxBool isOwnerVip = false.obs;

  @override
  void onInit() {
    super.onInit();
    _checkOwnerVip();
  }

  void _checkOwnerVip() {
    if (Get.isRegistered<SubscriptionRepository>()) {
      isOwnerVip.value = Get.find<SubscriptionRepository>().isOwnerVip;
    }
  }

  Future<void> toggleOwnerVip(bool enable) async {
    if (!Get.isRegistered<SubscriptionRepository>()) return;
    final repo = Get.find<SubscriptionRepository>();
    if (enable) {
      final verified = await OwnerPinDialog.show(
        title: '👑 Owner Master Verification',
        message: 'Enter your 4-digit Master PIN to activate Owner Lifetime VIP.',
      );
      if (verified) {
        await repo.activateOwnerVip();
        isOwnerVip.value = true;
        Get.snackbar(
          '👑 Owner VIP Activated',
          'Lifetime access granted to all features and playlists.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.amber.shade900,
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
      } else {
        isOwnerVip.value = false;
        Get.snackbar(
          'Access Denied',
          'Incorrect Master PIN. Owner VIP was not activated.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade900,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      }
    } else {
      await repo.deactivateOwnerVip();
      isOwnerVip.value = false;
      Get.snackbar(
        'Owner VIP Deactivated',
        'Reverted to standard free tier.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
    }
  }
}
