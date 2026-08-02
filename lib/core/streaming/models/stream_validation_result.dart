import 'package:flutter/foundation.dart';

/// The result of validating a [PlayableSession].
@immutable
class StreamValidationResult {
  final bool isValid;
  final String? url;
  final int? statusCode;
  final String? contentType;
  final int latencyMs;
  final List<String> errors;
  final List<String> warnings;
  final DateTime validatedAt;

  const StreamValidationResult({
    required this.isValid,
    this.url,
    this.statusCode,
    this.contentType,
    this.latencyMs = 0,
    this.errors = const [],
    this.warnings = const [],
    required this.validatedAt,
  });

  StreamValidationResult.valid({
    String? url,
    int? statusCode,
    String? contentType,
    int latencyMs = 0,
    List<String> warnings = const [],
  }) : this(
         isValid: true,
         url: url,
         statusCode: statusCode,
         contentType: contentType,
         latencyMs: latencyMs,
         warnings: warnings,
         validatedAt: DateTime.now(),
       );

  StreamValidationResult.invalid({
    required String reason,
    String? url,
    int? statusCode,
    List<String> additionalErrors = const [],
  }) : this(
         isValid: false,
         url: url,
         statusCode: statusCode,
         errors: [reason, ...additionalErrors],
         validatedAt: DateTime.now(),
       );
}
