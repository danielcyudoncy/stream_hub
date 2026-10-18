import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/logging/logging_service.dart';
import '../../core/network/doh_http_client.dart';
import '../models/subscription/paystack_transaction_response.dart';

/// Service responsible for communicating directly with Paystack REST APIs.
///
/// Follows StreamHub Pro core principles:
/// - Robust error logging and diagnostics via [LoggingService].
/// - DoH-aware HTTP client with timeout handling.
/// - Never fails silently.
class PaystackService extends GetxService {
  final LoggingService _logger;
  final HttpClient _client;
  final String _baseUrl;
  final String _secretKey;
  final String _publicKey;

  String get publicKey => _publicKey;
  String get baseUrl => _baseUrl;

  PaystackService({
    LoggingService? logger,
    HttpClient? client,
    String? baseUrl,
    String? secretKey,
    String? publicKey,
  })  : _logger = logger ?? (Get.isRegistered<LoggingService>() ? Get.find<LoggingService>() : LoggingService()),
        _client = client ?? createDohAwareHttpClient(),
        _baseUrl = baseUrl ?? AppConstants.paystackBaseUrl,
        _secretKey = secretKey ?? 'sk_test_53b5f9e3a20bd364149168dbf9c9794961926691',
        _publicKey = publicKey ?? AppConstants.paystackPublicKey;

  /// Initializes a transaction with Paystack.
  ///
  /// If [planCode] is supplied, Paystack attaches a recurring subscription to the
  /// customer's authorization.
  Future<PaystackInitResponse> initializeTransaction({
    required String email,
    required int amount,
    String? planCode,
    String? reference,
    String? callbackUrl,
    Map<String, dynamic>? metadata,
  }) async {
    final effectiveRef = reference ?? 'SH_${DateTime.now().millisecondsSinceEpoch}';
    final effectiveCallback = callbackUrl ?? AppConstants.paystackCallbackUrl;

    final body = <String, dynamic>{
      'email': email.trim().toLowerCase(),
      'amount': amount,
      'reference': effectiveRef,
      'callback_url': effectiveCallback,
    };

    if (planCode != null && planCode.isNotEmpty) {
      body['plan'] = planCode;
    }

    if (metadata != null) {
      body['metadata'] = metadata;
    }

    _logger.info(
      'Initializing Paystack transaction for $email with plan: $planCode (ref: $effectiveRef)',
      tag: 'PaystackService',
    );

    try {
      final uri = Uri.parse('$_baseUrl/transaction/initialize');
      final request = await _client.postUrl(uri).timeout(AppConstants.connectTimeout);
      
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_secretKey');
      request.add(utf8.encode(jsonEncode(body)));

      final response = await request.close().timeout(AppConstants.receiveTimeout);
      final responseBody = await utf8.decodeStream(response);
      final json = jsonDecode(responseBody) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _logger.info(
          'Paystack transaction initialized successfully (ref: $effectiveRef)',
          tag: 'PaystackService',
        );
        return PaystackInitResponse.fromJson(json);
      } else {
        final message = json['message'] as String? ?? 'Failed to initialize payment';
        _logger.error(
          'Paystack init failed [${response.statusCode}]: $message',
          tag: 'PaystackService',
        );
        throw NetworkException(message: message, code: 'PAYSTACK_${response.statusCode}');
      }
    } on TimeoutException catch (e) {
      _logger.error('Timeout connecting to Paystack API', tag: 'PaystackService', error: e);
      throw const NetworkException(message: 'Payment request timed out. Please check your internet connection.');
    } on SocketException catch (e) {
      _logger.error('Socket error communicating with Paystack', tag: 'PaystackService', error: e);
      throw const NetworkException(message: 'Unable to reach payment gateway. Please check your network.');
    } catch (e) {
      if (e is ApplicationException) rethrow;
      _logger.error('Unexpected error initializing Paystack payment', tag: 'PaystackService', error: e);
      throw UnknownException(originalError: e);
    }
  }

  /// Verifies a transaction by its reference.
  Future<PaystackVerifyResponse> verifyTransaction(String reference) async {
    _logger.info('Verifying Paystack transaction ref: $reference', tag: 'PaystackService');
    try {
      final uri = Uri.parse('$_baseUrl/transaction/verify/$reference');
      final request = await _client.getUrl(uri).timeout(AppConstants.connectTimeout);
      
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_secretKey');

      final response = await request.close().timeout(AppConstants.receiveTimeout);
      final responseBody = await utf8.decodeStream(response);
      final json = jsonDecode(responseBody) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final result = PaystackVerifyResponse.fromJson(json);
        _logger.info(
          'Paystack verification result for $reference: ${result.transactionStatus}',
          tag: 'PaystackService',
        );
        return result;
      } else {
        final message = json['message'] as String? ?? 'Failed to verify transaction';
        _logger.error(
          'Paystack verification failed [${response.statusCode}]: $message',
          tag: 'PaystackService',
        );
        throw NetworkException(message: message, code: 'PAYSTACK_${response.statusCode}');
      }
    } on TimeoutException catch (e) {
      _logger.error('Timeout verifying Paystack transaction', tag: 'PaystackService', error: e);
      throw const NetworkException(message: 'Verification timed out. Please try again.');
    } catch (e) {
      if (e is ApplicationException) rethrow;
      _logger.error('Unexpected error verifying transaction', tag: 'PaystackService', error: e);
      throw UnknownException(originalError: e);
    }
  }

  /// Fetches details for a given plan code.
  Future<Map<String, dynamic>> fetchPlan(String planCode) async {
    _logger.info('Fetching Paystack plan info: $planCode', tag: 'PaystackService');
    try {
      final uri = Uri.parse('$_baseUrl/plan/$planCode');
      final request = await _client.getUrl(uri).timeout(AppConstants.connectTimeout);
      
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_secretKey');

      final response = await request.close().timeout(AppConstants.receiveTimeout);
      final responseBody = await utf8.decodeStream(response);
      final json = jsonDecode(responseBody) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return (json['data'] as Map<String, dynamic>?) ?? {};
      } else {
        final message = json['message'] as String? ?? 'Plan not found';
        throw NetworkException(message: message, code: 'PAYSTACK_${response.statusCode}');
      }
    } catch (e) {
      _logger.error('Failed to fetch plan info', tag: 'PaystackService', error: e);
      if (e is ApplicationException) rethrow;
      throw UnknownException(originalError: e);
    }
  }

  /// Disables an active subscription on Paystack.
  Future<bool> disableSubscription({required String code, String? token}) async {
    _logger.info('Disabling Paystack subscription code: $code', tag: 'PaystackService');
    try {
      final uri = Uri.parse('$_baseUrl/subscription/disable');
      final request = await _client.postUrl(uri).timeout(AppConstants.connectTimeout);
      
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_secretKey');

      final body = <String, dynamic>{'code': code};
      if (token != null && token.isNotEmpty) {
        body['token'] = token;
      }
      request.add(utf8.encode(jsonEncode(body)));

      final response = await request.close().timeout(AppConstants.receiveTimeout);
      final responseBody = await utf8.decodeStream(response);
      final json = jsonDecode(responseBody) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _logger.info('Successfully disabled Paystack subscription: $code', tag: 'PaystackService');
        return true;
      } else {
        final message = json['message'] as String? ?? 'Failed to disable subscription';
        _logger.warning('Paystack disable subscription returned error: $message', tag: 'PaystackService');
        return false;
      }
    } catch (e) {
      _logger.error('Error disabling Paystack subscription', tag: 'PaystackService', error: e);
      return false;
    }
  }

  /// Generates a Paystack self-service manage subscription link.
  Future<String?> fetchSubscriptionManageLink(String subscriptionCode) async {
    _logger.info('Fetching manage link for subscription: $subscriptionCode', tag: 'PaystackService');
    try {
      final uri = Uri.parse('$_baseUrl/subscription/$subscriptionCode/manage/link');
      final request = await _client.getUrl(uri).timeout(AppConstants.connectTimeout);
      
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_secretKey');

      final response = await request.close().timeout(AppConstants.receiveTimeout);
      final responseBody = await utf8.decodeStream(response);
      final json = jsonDecode(responseBody) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = json['data'] as Map<String, dynamic>?;
        return data?['link'] as String?;
      }
      return null;
    } catch (e) {
      _logger.warning('Failed to get subscription manage link', tag: 'PaystackService', error: e);
      return null;
    }
  }
}
