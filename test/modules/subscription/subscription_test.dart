import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/guards/subscription_guard.dart';
import 'package:stream_hub/data/models/subscription/paystack_transaction_response.dart';
import 'package:stream_hub/data/models/subscription/subscription_model.dart';

void main() {
  group('SubscriptionModel Tests', () {
    test('SubscriptionModel.free creates valid inactive tier', () {
      final freeSub = SubscriptionModel.free(userId: 'u123', email: 'test@example.com');

      expect(freeSub.userId, 'u123');
      expect(freeSub.email, 'test@example.com');
      expect(freeSub.status, SubscriptionStatus.none);
      expect(freeSub.tier, SubscriptionTier.free);
      expect(freeSub.isActive, false);
      expect(freeSub.isPremium, false);
      expect(freeSub.formattedPrice, 'Free');
    });

    test('SubscriptionModel.trial creates active 30-day VIP trial with correct days', () {
      final trialSub = SubscriptionModel.trial(userId: 'u123', email: 'newuser@test.com');

      expect(trialSub.userId, 'u123');
      expect(trialSub.status, SubscriptionStatus.trial);
      expect(trialSub.tier, SubscriptionTier.premium);
      expect(trialSub.isActive, true);
      expect(trialSub.isPremium, true);
      expect(trialSub.isTrial, true);
      expect(trialSub.daysRemaining, inInclusiveRange(29, 30));
      expect(trialSub.formattedPrice, '30-Day Free Trial');
    });

    test('SubscriptionModel.trial becomes inactive after expiry', () {
      final pastDate = DateTime.now().subtract(const Duration(days: 31));
      final expiredTrial = SubscriptionModel.trial(
        userId: 'u123',
        email: 'expired@test.com',
        trialStartDate: pastDate,
      );

      expect(expiredTrial.isActive, false);
      expect(expiredTrial.isPremium, false);
      expect(expiredTrial.isTrial, false);
      expect(expiredTrial.daysRemaining, 0);
    });

    test('SubscriptionModel.ownerVip creates permanent lifetime VIP pass', () {
      final ownerSub = SubscriptionModel.ownerVip(userId: 'admin_123');

      expect(ownerSub.userId, 'admin_123');
      expect(ownerSub.status, SubscriptionStatus.active);
      expect(ownerSub.tier, SubscriptionTier.premium);
      expect(ownerSub.isActive, true);
      expect(ownerSub.isPremium, true);
      expect(ownerSub.isOwnerVip, true);
      expect(ownerSub.isTrial, false);
      expect(ownerSub.planCode, 'OWNER_LIFETIME_VIP');
      expect(ownerSub.amount, 0);
      expect(ownerSub.expiryDate?.year, 2099);
    });

    test('SubscriptionModel.fromJson deserializes active subscription correctly', () {
      final now = DateTime.now();
      final expiry = now.add(const Duration(days: 28));

      final json = {
        'userId': 'usr_001',
        'email': 'vip@example.com',
        'status': 'active',
        'tier': 'premium',
        'planCode': 'PLN_e4jdnvxfa9khg47',
        'planName': 'Premium Account',
        'amount': 100000,
        'currency': 'NGN',
        'interval': 'monthly',
        'reference': 'SH_123456789',
        'startDate': now.toIso8601String(),
        'expiryDate': expiry.toIso8601String(),
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
        'isAutoRenewing': true,
      };

      final sub = SubscriptionModel.fromJson(json);

      expect(sub.userId, 'usr_001');
      expect(sub.email, 'vip@example.com');
      expect(sub.status, SubscriptionStatus.active);
      expect(sub.tier, SubscriptionTier.premium);
      expect(sub.isActive, true);
      expect(sub.isPremium, true);
      expect(sub.daysRemaining, greaterThanOrEqualTo(27));
      expect(sub.formattedPrice, '₦1000 / monthly');
    });

    test('SubscriptionModel is inactive if expired', () {
      final past = DateTime.now().subtract(const Duration(days: 2));
      final sub = SubscriptionModel(
        userId: 'u1',
        email: 'u1@test.com',
        status: SubscriptionStatus.active,
        tier: SubscriptionTier.premium,
        planCode: 'PLN_test',
        planName: 'Premium Account',
        amount: 100000,
        currency: 'NGN',
        interval: 'monthly',
        startDate: past.subtract(const Duration(days: 30)),
        expiryDate: past,
        createdAt: past,
        updatedAt: past,
      );

      expect(sub.isActive, false);
      expect(sub.isPremium, false);
      expect(sub.daysRemaining, 0);
    });

    test('SubscriptionModel.copyWith updates isAutoRenewing state correctly', () {
      final now = DateTime.now();
      final sub = SubscriptionModel(
        userId: 'u1',
        email: 'u1@test.com',
        status: SubscriptionStatus.active,
        tier: SubscriptionTier.premium,
        planCode: 'PLN_test',
        planName: 'Premium Account',
        amount: 100000,
        currency: 'NGN',
        interval: 'monthly',
        isAutoRenewing: true,
        createdAt: now,
        updatedAt: now,
      );

      final cancelled = sub.copyWith(isAutoRenewing: false);

      expect(cancelled.isAutoRenewing, false);
      expect(cancelled.isPremium, true);
    });
  });

  group('Paystack Response Models Tests', () {
    test('PaystackInitResponse parses valid API payload', () {
      final json = {
        'status': true,
        'message': 'Authorization URL created',
        'data': {
          'authorization_url': 'https://checkout.paystack.com/000111222',
          'access_code': '000111222',
          'reference': 'SH_ref_999',
        }
      };

      final res = PaystackInitResponse.fromJson(json);

      expect(res.status, true);
      expect(res.authorizationUrl, 'https://checkout.paystack.com/000111222');
      expect(res.reference, 'SH_ref_999');
    });

    test('PaystackVerifyResponse parses successful transaction', () {
      final json = {
        'status': true,
        'message': 'Verification successful',
        'data': {
          'reference': 'SH_ref_999',
          'amount': 100000,
          'status': 'success',
          'currency': 'NGN',
          'customer': {
            'email': 'customer@domain.com',
            'customer_code': 'CUS_123',
          },
          'plan': 'PLN_e4jdnvxfa9khg47',
          'subscription_code': 'SUB_456',
        }
      };

      final res = PaystackVerifyResponse.fromJson(json);

      expect(res.isSuccessful, true);
      expect(res.reference, 'SH_ref_999');
      expect(res.amount, 100000);
      expect(res.customerEmail, 'customer@domain.com');
      expect(res.planCode, 'PLN_e4jdnvxfa9khg47');
      expect(res.subscriptionCode, 'SUB_456');
    });
  });

  group('SubscriptionGuard Entitlement Tests', () {
    test('Free Live TV is ALWAYS accessible without subscription per ARCHITECTURE.md', () {
      final allowed = SubscriptionGuard.canAccess(EntitledFeature.freeLiveTv);
      expect(allowed, true);
    });

    test('Custom IPTV providers require active subscription', () {
      // With no active registered subscription repository, defaults to false
      final allowed = SubscriptionGuard.canAccess(EntitledFeature.customIptvProviders);
      expect(allowed, false);
    });
  });
}
