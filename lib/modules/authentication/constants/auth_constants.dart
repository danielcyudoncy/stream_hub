import 'package:flutter/material.dart';

class AuthConstants {
  AuthConstants._();

  static const String boxAuth = 'auth_session';
  static const String keyLastEmail = 'last_email';
  static const String keyPreferredLoginMethod = 'preferred_login_method';
  static const String keyRememberMe = 'remember_me';
  static const String keySessionExpiresAt = 'session_expires_at';

  static const int minPasswordLength = 6;
  static const int maxPasswordLength = 128;
  static const int minNameLength = 2;
  static const int maxNameLength = 50;

  static const Duration sessionDuration = Duration(days: 30);
  static const Duration verificationCheckInterval = Duration(seconds: 3);

  static const double passwordStrengthWeak = 0.25;
  static const double passwordStrengthFair = 0.5;
  static const double passwordStrengthGood = 0.75;
  static const double passwordStrengthStrong = 1.0;

  static LinearGradient get primaryGradient => const LinearGradient(
        colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get secondaryGradient => const LinearGradient(
        colors: [Color(0xFF14B8A6), Color(0xFF0D9488)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}
