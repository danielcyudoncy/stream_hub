import 'package:flutter/foundation.dart';

@immutable
class PaystackInitResponse {
  final bool status;
  final String message;
  final String? authorizationUrl;
  final String? accessCode;
  final String? reference;

  const PaystackInitResponse({
    required this.status,
    required this.message,
    this.authorizationUrl,
    this.accessCode,
    this.reference,
  });

  factory PaystackInitResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    return PaystackInitResponse(
      status: json['status'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      authorizationUrl: data?['authorization_url'] as String?,
      accessCode: data?['access_code'] as String?,
      reference: data?['reference'] as String?,
    );
  }
}

@immutable
class PaystackVerifyResponse {
  final bool status;
  final String message;
  final String? reference;
  final int? amount;
  final String? currency;
  final String? transactionStatus; // 'success', 'failed', 'abandoned'
  final String? customerEmail;
  final String? planCode;
  final String? subscriptionCode;
  final String? customerCode;
  final DateTime? paidAt;
  final String? channel;

  const PaystackVerifyResponse({
    required this.status,
    required this.message,
    this.reference,
    this.amount,
    this.currency,
    this.transactionStatus,
    this.customerEmail,
    this.planCode,
    this.subscriptionCode,
    this.customerCode,
    this.paidAt,
    this.channel,
  });

  bool get isSuccessful => status && transactionStatus == 'success';

  factory PaystackVerifyResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    final customer = data?['customer'] as Map<String, dynamic>?;
    final rawPlan = data?['plan'];
    final planMap = rawPlan is Map<String, dynamic> ? rawPlan : null;
    final planCode = rawPlan is String ? rawPlan : planMap?['plan_code'] as String?;

    return PaystackVerifyResponse(
      status: json['status'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      reference: data?['reference'] as String?,
      amount: (data?['amount'] as num?)?.toInt(),
      currency: data?['currency'] as String?,
      transactionStatus: data?['status'] as String?,
      customerEmail: customer?['email'] as String?,
      customerCode: customer?['customer_code'] as String?,
      planCode: planCode,
      subscriptionCode: data?['subscription_code'] as String?,
      paidAt: data?['paid_at'] != null
          ? DateTime.tryParse(data!['paid_at'] as String)
          : null,
      channel: data?['channel'] as String?,
    );
  }
}
