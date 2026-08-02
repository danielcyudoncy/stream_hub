import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/streaming/auth/authentication_engine.dart';
import 'package:stream_hub/core/streaming/auth/authentication_result.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';

/// Authentication for M3U providers.
///
/// M3U playlists either embed credentials in the URL or rely on basic auth.
/// Sessions never expire, so refresh is a no-op that preserves the session.
class M3UAuthenticationProvider implements AuthenticationProvider {
  @override
  MediaSourceType get providerType => MediaSourceType.m3u;

  @override
  bool get supportsRefresh => false;

  @override
  Future<AuthenticationResult> validate(ProviderSession session) async {
    final hasBasicAuth = session.username != null && session.password != null;
    final hasUrlAuth =
        session.baseUrl != null &&
        Uri.tryParse(session.baseUrl!)?.userInfo.isNotEmpty == true;
    if (!session.requiresAuth || hasBasicAuth || hasUrlAuth) {
      return const AuthenticationResult.authenticated();
    }
    return const AuthenticationResult.failed(
      'M3U provider has no valid authentication configured.',
    );
  }

  @override
  Future<ProviderSession> refresh(ProviderSession session) async => session;
}
