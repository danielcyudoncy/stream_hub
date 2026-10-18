import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../../core/constants/app_constants.dart';
import '../../core/logging/logging_service.dart';
import '../models/subscription/paystack_transaction_response.dart';
import '../models/subscription/subscription_model.dart';
import 'firebase_service.dart';
import 'paystack_service.dart';

/// Service responsible for remote operations: Paystack API & Cloud Firestore syncing.
class SubscriptionRemoteService extends GetxService {
  final PaystackService _paystackService;
  final FirebaseService? _firebaseService;
  final FirebaseFirestore? _firestore;
  final LoggingService _logger;

  SubscriptionRemoteService({
    PaystackService? paystackService,
    FirebaseService? firebaseService,
    FirebaseFirestore? firestore,
    LoggingService? logger,
  })  : _paystackService = paystackService ?? (Get.isRegistered<PaystackService>() ? Get.find<PaystackService>() : PaystackService()),
        _firebaseService = firebaseService ?? (Get.isRegistered<FirebaseService>() ? Get.find<FirebaseService>() : null),
        _firestore = firestore,
        _logger = logger ?? (Get.isRegistered<LoggingService>() ? Get.find<LoggingService>() : LoggingService());

  FirebaseFirestore? get _effectiveFirestore {
    if (!(_firebaseService?.isAvailable ?? false)) return null;
    try {
      return _firestore ?? FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  /// Initiates a transaction on Paystack for the subscription plan.
  Future<PaystackInitResponse> initializeSubscription({
    required String email,
    required String userId,
    String? planCode,
    int? amount,
  }) async {
    final effectivePlan = planCode ?? AppConstants.paystackDefaultPlanCode;
    final effectiveAmount = amount ?? AppConstants.paystackDefaultPlanAmount;

    return await _paystackService.initializeTransaction(
      email: email,
      amount: effectiveAmount,
      planCode: effectivePlan,
      metadata: {
        'user_id': userId,
        'app': AppConstants.appName,
      },
    );
  }

  /// Verifies transaction on Paystack and converts it into a canonical [SubscriptionModel].
  Future<SubscriptionModel?> verifyAndBuildSubscription({
    required String reference,
    required String userId,
    required String email,
  }) async {
    final verifyRes = await _paystackService.verifyTransaction(reference);
    if (!verifyRes.isSuccessful) {
      _logger.warning(
        'Transaction verification returned non-success status: ${verifyRes.transactionStatus}',
        tag: 'SubscriptionRemoteService',
      );
      return null;
    }

    final now = DateTime.now();
    // Default 30-day monthly cycle for PLN_e4jdnvxfa9khg47
    final expiryDate = now.add(const Duration(days: 30));

    final subscription = SubscriptionModel(
      userId: userId,
      email: email,
      status: SubscriptionStatus.active,
      tier: SubscriptionTier.premium,
      planCode: verifyRes.planCode ?? AppConstants.paystackDefaultPlanCode,
      planName: AppConstants.paystackDefaultPlanName,
      amount: verifyRes.amount ?? AppConstants.paystackDefaultPlanAmount,
      currency: verifyRes.currency ?? AppConstants.paystackDefaultPlanCurrency,
      interval: AppConstants.paystackDefaultPlanInterval,
      subscriptionCode: verifyRes.subscriptionCode,
      customerCode: verifyRes.customerCode,
      reference: reference,
      startDate: verifyRes.paidAt ?? now,
      expiryDate: expiryDate,
      createdAt: now,
      updatedAt: now,
      isAutoRenewing: true,
    );

    // Save to Firestore in background if available
    await syncToFirestore(subscription);

    return subscription;
  }

  /// Synchronizes subscription document to Firestore under users/{userId}/subscription
  Future<void> syncToFirestore(SubscriptionModel subscription) async {
    final firestore = _effectiveFirestore;
    if (firestore == null || subscription.userId.isEmpty) return;

    try {
      await firestore
          .collection('users')
          .doc(subscription.userId)
          .collection('subscription')
          .doc('current')
          .set(subscription.toJson(), SetOptions(merge: true));
      _logger.info('Subscription successfully synced to Firestore', tag: 'SubscriptionRemoteService');
    } catch (e) {
      _logger.warning('Failed to sync subscription to Firestore', tag: 'SubscriptionRemoteService', error: e);
    }
  }

  /// Reads remote subscription state from Firestore.
  Future<SubscriptionModel?> fetchFromFirestore(String userId) async {
    final firestore = _effectiveFirestore;
    if (firestore == null || userId.isEmpty) return null;

    try {
      final doc = await firestore
          .collection('users')
          .doc(userId)
          .collection('subscription')
          .doc('current')
          .get();

      if (doc.exists && doc.data() != null) {
        return SubscriptionModel.fromJson(doc.data()!);
      }
    } catch (e) {
      _logger.warning('Could not fetch subscription from Firestore', tag: 'SubscriptionRemoteService', error: e);
    }
    return null;
  }

  /// Disables recurring subscription via Paystack API if subscription code is present.
  Future<bool> disableSubscription({required String subscriptionCode, String? token}) async {
    try {
      return await _paystackService.disableSubscription(code: subscriptionCode, token: token);
    } catch (e) {
      _logger.warning('Failed to disable subscription via Paystack', tag: 'SubscriptionRemoteService', error: e);
      return false;
    }
  }

  /// Generates a customer management link on Paystack.
  Future<String?> getManageLink(String subscriptionCode) async {
    try {
      return await _paystackService.fetchSubscriptionManageLink(subscriptionCode);
    } catch (e) {
      _logger.warning('Failed to fetch manage link from Paystack', tag: 'SubscriptionRemoteService', error: e);
      return null;
    }
  }
}
