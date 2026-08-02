import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/streaming/auth/authentication_engine.dart';
import 'package:stream_hub/core/streaming/auth/authentication_result.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';

/// Authentication for token-based media servers (Plex, Jellyfin, Emby).
///
/// These servers authenticate every stream request with a bearer/API token.
/// Sessions are valid until the token is revoked, so refresh is a no-op.
class BearerTokenAuthenticationProvider implements AuthenticationProvider {
  final MediaSourceType type;

  const BearerTokenAuthenticationProvider(this.type);

  @override
  MediaSourceType get providerType => type;

  @override
  bool get supportsRefresh => false;

  @override
  Future<AuthenticationResult> validate(ProviderSession session) async {
    if (session.bearerToken == null || session.bearerToken!.isEmpty) {
      return AuthenticationResult.failed(
        '${type.displayName} provider requires an API token.',
      );
    }
    return AuthenticationResult.authenticated(expiresAt: session.expiresAt);
  }

  @override
  Future<ProviderSession> refresh(ProviderSession session) async => session;
}
