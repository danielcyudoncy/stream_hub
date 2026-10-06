import '../../firebase_options.dart';

/// Configuration for third-party authentication providers.
class AuthConfig {
  AuthConfig._();

  /// Google OAuth Web Client ID (serverClientId) used for Google Sign-In.
  ///
  /// Priority:
  /// 1. `--dart-define=GOOGLE_SERVER_CLIENT_ID=<id>` or `--dart-define-from-file=.env`
  /// 2. [DefaultFirebaseOptions.googleServerClientId] from the gitignored local Firebase configuration.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: DefaultFirebaseOptions.googleServerClientId,
  );
}
