import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/logging/logging_service.dart';
import '../models/subscription/paystack_transaction_response.dart';
import '../models/subscription/subscription_model.dart';
import '../services/subscription_local_service.dart';
import '../services/subscription_remote_service.dart';

abstract class SubscriptionRepository {
  SubscriptionModel get currentSubscription;
  bool get isSubscribed;
  bool get isOwnerVip;
  Future<SubscriptionModel> getSubscription({bool forceRefresh = false});
  Stream<SubscriptionModel> watchSubscription();
  Future<PaystackInitResponse> initializeSubscription({required String email, String? planCode});
  Future<SubscriptionModel> verifyAndActivate({required String reference, required String email});
  Future<void> activateOwnerVip();
  Future<void> deactivateOwnerVip();
  Future<void> cancelSubscription();
  Future<String?> getManageLink();
  Future<void> refresh();
}

class SubscriptionRepositoryImpl extends GetxService implements SubscriptionRepository {
  final SubscriptionLocalService _localService;
  final SubscriptionRemoteService _remoteService;
  final LoggingService _logger;

  final StreamController<SubscriptionModel> _subscriptionStreamController =
      StreamController<SubscriptionModel>.broadcast();

  SubscriptionModel _currentSubscription = SubscriptionModel.free(userId: '', email: '');

  SubscriptionRepositoryImpl({
    SubscriptionLocalService? localService,
    SubscriptionRemoteService? remoteService,
    LoggingService? logger,
  })  : _localService = localService ?? Get.find<SubscriptionLocalService>(),
        _remoteService = remoteService ?? Get.find<SubscriptionRemoteService>(),
        _logger = logger ?? (Get.isRegistered<LoggingService>() ? Get.find<LoggingService>() : LoggingService());

  @override
  SubscriptionModel get currentSubscription => _currentSubscription;

  @override
  bool get isSubscribed => _currentSubscription.isPremium;

  @override
  bool get isOwnerVip => _currentSubscription.isOwnerVip;

  @override
  Stream<SubscriptionModel> watchSubscription() => _subscriptionStreamController.stream;

  @override
  void onInit() {
    super.onInit();
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    final cached = await _localService.getSubscription();
    if (cached != null) {
      _updateCurrent(cached);
    } else {
      // First time launch: Start 30-day VIP Free Trial!
      final userId = _getEffectiveUserId();
      final trialSub = SubscriptionModel.trial(userId: userId, email: '');
      await _localService.saveSubscription(trialSub);
      _updateCurrent(trialSub);
      _remoteService.syncToFirestore(trialSub);
    }
  }

  void _updateCurrent(SubscriptionModel model) {
    _currentSubscription = model;
    _subscriptionStreamController.add(model);
  }

  String _getEffectiveUserId() {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.uid.isNotEmpty) {
        return user.uid;
      }
    } catch (_) {}
    return 'local_user';
  }

  @override
  Future<SubscriptionModel> getSubscription({bool forceRefresh = false}) async {
    // 1. Return cached instantly (offline-first)
    if (!forceRefresh && _currentSubscription.status != SubscriptionStatus.none) {
      return _currentSubscription;
    }

    final local = await _localService.getSubscription();
    if (local != null) {
      _updateCurrent(local);
      if (!forceRefresh) return local;
    }

    // 2. Refresh from Firestore if available
    final userId = _getEffectiveUserId();
    final remote = await _remoteService.fetchFromFirestore(userId);
    if (remote != null) {
      await _localService.saveSubscription(remote);
      _updateCurrent(remote);
      return remote;
    }

    // 3. If neither local nor remote exists, grant the 30-day VIP trial
    if (_currentSubscription.status == SubscriptionStatus.none) {
      final trialSub = SubscriptionModel.trial(userId: userId, email: '');
      await _localService.saveSubscription(trialSub);
      await _remoteService.syncToFirestore(trialSub);
      _updateCurrent(trialSub);
      return trialSub;
    }

    return _currentSubscription;
  }

  @override
  Future<PaystackInitResponse> initializeSubscription({
    required String email,
    String? planCode,
  }) async {
    final userId = _getEffectiveUserId();
    _logger.info('Initializing subscription checkout for $email', tag: 'SubscriptionRepository');
    try {
      return await _remoteService.initializeSubscription(
        email: email,
        userId: userId,
        planCode: planCode ?? AppConstants.paystackDefaultPlanCode,
        amount: AppConstants.paystackDefaultPlanAmount,
      );
    } catch (e) {
      _logger.error('Failed to initialize subscription checkout', tag: 'SubscriptionRepository', error: e);
      rethrow;
    }
  }

  @override
  Future<SubscriptionModel> verifyAndActivate({
    required String reference,
    required String email,
  }) async {
    final userId = _getEffectiveUserId();
    _logger.info('Verifying and activating subscription (ref: $reference)', tag: 'SubscriptionRepository');
    try {
      final activeSub = await _remoteService.verifyAndBuildSubscription(
        reference: reference,
        userId: userId,
        email: email,
      );

      if (activeSub == null) {
        throw const ValidationException(message: 'Payment verification failed or transaction was not completed.');
      }

      await _localService.saveSubscription(activeSub);
      _updateCurrent(activeSub);
      _logger.info('Subscription successfully activated: ${activeSub.planName}', tag: 'SubscriptionRepository');
      return activeSub;
    } catch (e) {
      _logger.error('Error activating subscription', tag: 'SubscriptionRepository', error: e);
      if (e is ApplicationException) rethrow;
      throw UnknownException(originalError: e);
    }
  }

  @override
  Future<void> activateOwnerVip() async {
    final userId = _getEffectiveUserId();
    final ownerSub = SubscriptionModel.ownerVip(userId: userId);
    await _localService.saveSubscription(ownerSub);
    await _remoteService.syncToFirestore(ownerSub);
    _updateCurrent(ownerSub);
    _logger.info('Owner Lifetime VIP activated successfully', tag: 'SubscriptionRepository');
  }

  @override
  Future<void> deactivateOwnerVip() async {
    final userId = _getEffectiveUserId();
    final freeSub = SubscriptionModel.free(userId: userId, email: '');
    await _localService.saveSubscription(freeSub);
    await _remoteService.syncToFirestore(freeSub);
    _updateCurrent(freeSub);
    _logger.info('Deactivated Owner VIP; reverted to Free tier', tag: 'SubscriptionRepository');
  }

  @override
  Future<void> cancelSubscription() async {
    _logger.info('Cancelling subscription auto-renewal', tag: 'SubscriptionRepository');
    final subCode = _currentSubscription.subscriptionCode;
    if (subCode != null && subCode.isNotEmpty) {
      await _remoteService.disableSubscription(subscriptionCode: subCode);
    }

    final updated = _currentSubscription.copyWith(
      isAutoRenewing: false,
      updatedAt: DateTime.now(),
    );
    await _localService.saveSubscription(updated);
    await _remoteService.syncToFirestore(updated);
    _updateCurrent(updated);
  }

  @override
  Future<String?> getManageLink() async {
    final subCode = _currentSubscription.subscriptionCode;
    if (subCode == null || subCode.isEmpty) return null;
    return await _remoteService.getManageLink(subCode);
  }

  @override
  Future<void> refresh() async {
    await getSubscription(forceRefresh: true);
  }

  @override
  void onClose() {
    _subscriptionStreamController.close();
    super.onClose();
  }
}
