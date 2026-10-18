import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/logging/logging_service.dart';
import '../../data/models/subscription/subscription_model.dart';
import '../../data/repositories/subscription_repository.dart';

class SubscriptionController extends GetxController {
  final SubscriptionRepository _repository;
  final LoggingService _logger = Get.isRegistered<LoggingService>()
      ? Get.find<LoggingService>()
      : LoggingService();

  SubscriptionController({
    required SubscriptionRepository subscriptionRepository,
  }) : _repository = subscriptionRepository;

  final Rx<SubscriptionModel> subscription = SubscriptionModel.free(
    userId: '',
    email: '',
  ).obs;

  final RxBool isLoading = false.obs;
  final RxBool isProcessingPayment = false.obs;
  final RxString errorMessage = ''.obs;
  final RxString successMessage = ''.obs;
  final RxString activeReference = ''.obs;
  final RxString userEmail = ''.obs;
  final RxBool isCancelling = false.obs;

  StreamSubscription<SubscriptionModel>? _streamSub;

  bool get isSubscribed => subscription.value.isPremium;
  String get planName => subscription.value.planName;
  String get formattedPrice => '₦1,000 / month';
  int get daysRemaining => subscription.value.daysRemaining;

  @override
  void onInit() {
    super.onInit();
    _loadSubscription();
    _streamSub = _repository.watchSubscription().listen((updated) {
      subscription.value = updated;
    });
  }

  Future<void> _loadSubscription() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final sub = await _repository.getSubscription();
      subscription.value = sub;
    } catch (e) {
      _logger.warning('Failed loading initial subscription state', tag: 'SubscriptionController', error: e);
    } finally {
      isLoading.value = false;
    }
  }

  /// Initiates the Paystack payment flow.
  ///
  /// Opens Paystack's secure checkout page in the browser or mobile custom tab.
  Future<void> initiatePaystackCheckout({String? email}) async {
    final effectiveEmail = (email ?? userEmail.value).trim();
    if (effectiveEmail.isEmpty || !GetUtils.isEmail(effectiveEmail)) {
      errorMessage.value = 'Please provide a valid email address for your subscription receipt.';
      Get.snackbar(
        'Email Required',
        errorMessage.value,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent.withValues(alpha: 0.9),
        colorText: Colors.white,
      );
      return;
    }

    userEmail.value = effectiveEmail;
    isLoading.value = true;
    errorMessage.value = '';

    try {
      final initRes = await _repository.initializeSubscription(
        email: effectiveEmail,
        planCode: AppConstants.paystackDefaultPlanCode,
      );

      final authUrl = initRes.authorizationUrl;
      final ref = initRes.reference;

      if (authUrl == null || ref == null) {
        throw const NetworkException(message: 'Failed to obtain checkout URL from Paystack.');
      }

      activeReference.value = ref;

      final uri = Uri.parse(authUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        
        Get.snackbar(
          'Checkout Opened',
          'Complete your payment in the browser, then tap "Verify Payment" below.',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 8),
          backgroundColor: Colors.blueAccent.withValues(alpha: 0.9),
          colorText: Colors.white,
        );
      } else {
        throw const NetworkException(message: 'Could not open checkout page in browser.');
      }
    } on ApplicationException catch (e) {
      errorMessage.value = e.message;
      Get.snackbar(
        'Checkout Error',
        e.message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent.withValues(alpha: 0.9),
        colorText: Colors.white,
      );
    } catch (e) {
      errorMessage.value = 'An unexpected error occurred while starting checkout.';
      _logger.error('Checkout error', tag: 'SubscriptionController', error: e);
    } finally {
      isLoading.value = false;
    }
  }

  /// Verifies a completed Paystack transaction and activates Premium.
  Future<void> verifyPayment() async {
    final ref = activeReference.value;
    final email = userEmail.value;

    if (ref.isEmpty) {
      Get.snackbar(
        'No Active Transaction',
        'Please start a subscription first.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    isProcessingPayment.value = true;
    errorMessage.value = '';

    try {
      final activated = await _repository.verifyAndActivate(
        reference: ref,
        email: email,
      );

      subscription.value = activated;
      successMessage.value = 'Welcome to StreamHub Pro Premium!';

      Get.snackbar(
        'Subscription Activated!',
        'You now have unlimited access to custom IPTV playlists and premium features.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.withValues(alpha: 0.9),
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    } on ApplicationException catch (e) {
      errorMessage.value = e.message;
      Get.snackbar(
        'Verification Incomplete',
        e.message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orangeAccent.withValues(alpha: 0.9),
        colorText: Colors.white,
      );
    } catch (e) {
      errorMessage.value = 'Failed to verify transaction. Please try again.';
      _logger.error('Verification error', tag: 'SubscriptionController', error: e);
    } finally {
      isProcessingPayment.value = false;
    }
  }

  /// Refreshes entitlement from cache / remote
  Future<void> refreshStatus() async {
    isLoading.value = true;
    try {
      await _repository.refresh();
      final updated = await _repository.getSubscription(forceRefresh: true);
      subscription.value = updated;
    } finally {
      isLoading.value = false;
    }
  }

  /// Cancels recurring subscription auto-renewal
  Future<void> cancelSubscription() async {
    isCancelling.value = true;
    try {
      await _repository.cancelSubscription();
      final updated = await _repository.getSubscription(forceRefresh: true);
      subscription.value = updated;

      Get.snackbar(
        'Auto-Renewal Cancelled',
        'Your VIP access remains active until your billing cycle ends, and your card will not be charged again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange.withValues(alpha: 0.9),
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    } catch (e) {
      _logger.error('Failed to cancel subscription', tag: 'SubscriptionController', error: e);
      Get.snackbar(
        'Error',
        'Could not cancel subscription. Please check your connection or contact support.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent.withValues(alpha: 0.9),
        colorText: Colors.white,
      );
    } finally {
      isCancelling.value = false;
    }
  }

  /// Opens Paystack self-service management portal if available
  Future<void> openManageBilling() async {
    try {
      final link = await _repository.getManageLink();
      if (link != null && link.isNotEmpty) {
        final uri = Uri.parse(link);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      }
      Get.snackbar(
        'Manage Billing',
        'You can manage your subscription directly from the receipt email sent by Paystack.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.blueGrey.withValues(alpha: 0.9),
        colorText: Colors.white,
      );
    } catch (e) {
      _logger.error('Error opening billing manage link', tag: 'SubscriptionController', error: e);
    }
  }

  @override
  void onClose() {
    _streamSub?.cancel();
    super.onClose();
  }
}
