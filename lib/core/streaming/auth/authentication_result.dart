import 'package:flutter/foundation.dart';

enum AuthenticationStatus {
  notAuthenticated,
  authenticating,
  authenticated,
  expired,
  failed;

  bool get isAuthenticated => this == AuthenticationStatus.authenticated;
}

/// Result of validating or refreshing a provider session.
@immutable
class AuthenticationResult {
  final AuthenticationStatus status;
  final DateTime? expiresAt;
  final String? error;

  const AuthenticationResult({
    required this.status,
    this.expiresAt,
    this.error,
  });

  const AuthenticationResult.authenticated({DateTime? expiresAt})
    : this(status: AuthenticationStatus.authenticated, expiresAt: expiresAt);

  const AuthenticationResult.failed(String error)
    : this(status: AuthenticationStatus.failed, error: error);

  bool get isAuthenticated => status.isAuthenticated;
}
