import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/streaming/auth/authentication_engine.dart';
import 'package:stream_hub/core/streaming/auth/authentication_result.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';

/// Authentication for Xtream Codes providers.
///
/// Xtream streams are authenticated by embedding the server URL, username, and
/// password as query parameters on the stream URL. This provider validates that
/// credentials exist and renews sessions by regenerating a fresh session id.
class XtreamAuthenticationProvider implements AuthenticationProvider {
  @override
  MediaSourceType get providerType => MediaSourceType.xtream;

  @override
  bool get supportsRefresh => true;

  @override
  Future<AuthenticationResult> validate(ProviderSession session) async {
    if (session.username == null || session.password == null) {
      return const AuthenticationResult.failed(
        'Xtream provider requires username and password.',
      );
    }
    return const AuthenticationResult.authenticated();
  }

  @override
  Future<ProviderSession> refresh(ProviderSession session) async {
    return session.copyWith(
      sessionId:
          'xtream_${session.providerId}_${DateTime.now().millisecondsSinceEpoch}',
      expiresAt: DateTime.now().add(const Duration(days: 30)),
    );
  }
}
