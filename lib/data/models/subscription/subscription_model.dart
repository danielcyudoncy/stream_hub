import 'package:flutter/foundation.dart';

enum SubscriptionStatus {
  none,
  trial,
  active,
  pastDue,
  expired,
  cancelled;

  bool get isActive => this == SubscriptionStatus.active || this == SubscriptionStatus.trial;
  bool get isTrial => this == SubscriptionStatus.trial;
}

enum SubscriptionTier {
  free,
  premium;

  bool get isPremium => this == SubscriptionTier.premium;
}

@immutable
class SubscriptionModel {
  final String userId;
  final String email;
  final SubscriptionStatus status;
  final SubscriptionTier tier;
  final String planCode;
  final String planName;
  final int amount; // Amount in minor units (kobo: 100000 = ₦1,000.00)
  final String currency;
  final String interval;
  final String? subscriptionCode;
  final String? customerCode;
  final String? reference;
  final DateTime? startDate;
  final DateTime? expiryDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isAutoRenewing;

  const SubscriptionModel({
    required this.userId,
    required this.email,
    required this.status,
    required this.tier,
    required this.planCode,
    required this.planName,
    required this.amount,
    required this.currency,
    required this.interval,
    this.subscriptionCode,
    this.customerCode,
    this.reference,
    this.startDate,
    this.expiryDate,
    required this.createdAt,
    required this.updatedAt,
    this.isAutoRenewing = true,
  });

  /// Factory for a default free (unsubscribed) account
  factory SubscriptionModel.free({
    required String userId,
    required String email,
  }) {
    final now = DateTime.now();
    return SubscriptionModel(
      userId: userId,
      email: email,
      status: SubscriptionStatus.none,
      tier: SubscriptionTier.free,
      planCode: '',
      planName: 'Free Tier',
      amount: 0,
      currency: 'NGN',
      interval: 'none',
      createdAt: now,
      updatedAt: now,
      isAutoRenewing: false,
    );
  }

  /// Factory for a 30-day VIP free trial for new users
  factory SubscriptionModel.trial({
    required String userId,
    required String email,
    DateTime? trialStartDate,
  }) {
    final start = trialStartDate ?? DateTime.now();
    final expiry = start.add(const Duration(days: 30));
    return SubscriptionModel(
      userId: userId,
      email: email,
      status: SubscriptionStatus.trial,
      tier: SubscriptionTier.premium,
      planCode: 'TRIAL_30_DAYS',
      planName: '30-Day VIP Free Trial',
      amount: 0,
      currency: 'NGN',
      interval: 'trial',
      startDate: start,
      expiryDate: expiry,
      createdAt: start,
      updatedAt: start,
      isAutoRenewing: false,
    );
  }

  /// Whether the subscription or trial is currently active and within its valid date range
  bool get isActive {
    if (status != SubscriptionStatus.active && status != SubscriptionStatus.trial) {
      return false;
    }
    if (expiryDate != null && DateTime.now().isAfter(expiryDate!)) {
      return false;
    }
    return true;
  }

  /// Whether the user has active Premium entitlements (paid or trial)
  bool get isPremium => tier.isPremium && isActive;

  /// Whether this is an active trial
  bool get isTrial => status == SubscriptionStatus.trial && isActive;

  /// Returns remaining days until next billing or expiry date
  int get daysRemaining {
    if (expiryDate == null) return 0;
    final diff = expiryDate!.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }

  /// Formatted price representation (e.g. ₦1,000 / month)
  String get formattedPrice {
    if (isTrial) return '30-Day Free Trial';
    if (amount <= 0) return 'Free';
    final majorAmount = (amount / 100).toStringAsFixed(0);
    final symbol = currency == 'NGN' ? '₦' : '\$';
    return '$symbol$majorAmount / $interval';
  }

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionModel(
      userId: json['userId'] as String? ?? '',
      email: json['email'] as String? ?? '',
      status: SubscriptionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => SubscriptionStatus.none,
      ),
      tier: SubscriptionTier.values.firstWhere(
        (e) => e.name == json['tier'],
        orElse: () => SubscriptionTier.free,
      ),
      planCode: json['planCode'] as String? ?? '',
      planName: json['planName'] as String? ?? 'Free Tier',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      currency: json['currency'] as String? ?? 'NGN',
      interval: json['interval'] as String? ?? 'monthly',
      subscriptionCode: json['subscriptionCode'] as String?,
      customerCode: json['customerCode'] as String?,
      reference: json['reference'] as String?,
      startDate: json['startDate'] != null
          ? DateTime.tryParse(json['startDate'] as String)
          : null,
      expiryDate: json['expiryDate'] != null
          ? DateTime.tryParse(json['expiryDate'] as String)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      isAutoRenewing: json['isAutoRenewing'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'email': email,
      'status': status.name,
      'tier': tier.name,
      'planCode': planCode,
      'planName': planName,
      'amount': amount,
      'currency': currency,
      'interval': interval,
      'subscriptionCode': subscriptionCode,
      'customerCode': customerCode,
      'reference': reference,
      'startDate': startDate?.toIso8601String(),
      'expiryDate': expiryDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isAutoRenewing': isAutoRenewing,
    };
  }

  SubscriptionModel copyWith({
    String? userId,
    String? email,
    SubscriptionStatus? status,
    SubscriptionTier? tier,
    String? planCode,
    String? planName,
    int? amount,
    String? currency,
    String? interval,
    String? subscriptionCode,
    String? customerCode,
    String? reference,
    DateTime? startDate,
    DateTime? expiryDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isAutoRenewing,
  }) {
    return SubscriptionModel(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      status: status ?? this.status,
      tier: tier ?? this.tier,
      planCode: planCode ?? this.planCode,
      planName: planName ?? this.planName,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      interval: interval ?? this.interval,
      subscriptionCode: subscriptionCode ?? this.subscriptionCode,
      customerCode: customerCode ?? this.customerCode,
      reference: reference ?? this.reference,
      startDate: startDate ?? this.startDate,
      expiryDate: expiryDate ?? this.expiryDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isAutoRenewing: isAutoRenewing ?? this.isAutoRenewing,
    );
  }
}
