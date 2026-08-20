import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/streaming/auth/authentication_engine.dart';
import 'package:stream_hub/core/streaming/auth/authentication_result.dart';
import 'package:stream_hub/core/streaming/errors/stream_exceptions.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';
import 'package:stream_hub/data/providers/stalker/stalker_portal_client.dart';

/// Authentication for Stalker Portal providers.
///
/// Stalker portals require a MAC address plus a short-lived portal token that
/// is obtained during handshake. [refresh] performs a real handshake against
/// the portal to renew the token instead of fabricating one.
class StalkerAuthenticationProvider implements AuthenticationProvider {
  static const Duration _kTokenLifetime = Duration(hours: 8);

  final LoggingService _logger;

  StalkerAuthenticationProvider({LoggingService? logger})
    : _logger = logger ?? LoggingService();

  @override
  MediaSourceType get providerType => MediaSourceType.stalker;

  @override
  bool get supportsRefresh => true;

  @override
  Future<AuthenticationResult> validate(ProviderSession session) async {
    if (session.macAddress == null || session.macAddress!.isEmpty) {
      return const AuthenticationResult.failed(
        'Stalker provider requires a MAC address.',
      );
    }
    if (session.portalToken == null || session.isExpired) {
      return const AuthenticationResult(
        status: AuthenticationStatus.expired,
        error: 'Stalker portal token has expired.',
      );
    }
    return AuthenticationResult.authenticated(expiresAt: session.expiresAt);
  }

  @override
  Future<ProviderSession> refresh(ProviderSession session) async {
    if (session.baseUrl == null || session.baseUrl!.isEmpty) {
      throw const StreamAuthException(
        message: 'Stalker refresh requires the portal URL.',
      );
    }
    if (session.macAddress == null || session.macAddress!.isEmpty) {
      throw const StreamAuthException(
        message: 'Stalker refresh requires the MAC address.',
      );
    }

    final client = StalkerPortalClient(
      baseUrl: session.baseUrl!,
      macAddress: session.macAddress!,
      serial: session.deviceId,
      token: null,
      logger: _logger,
    );

    try {
      final handshake = await client.handshake();
      _logger.info(
        'Stalker portal token refreshed for ${session.providerId}',
        tag: 'StalkerAuthenticationProvider',
      );
      final updatedCookies = <String, String>{
        ...session.cookies,
        if (session.macAddress != null && session.macAddress!.isNotEmpty)
          'mac': session.macAddress!,
        if ((handshake.serial ?? session.deviceId) != null)
          'sn': handshake.serial ?? session.deviceId!,
        'stb_lang': 'en',
        'timezone': 'UTC',
        'token': handshake.token,
      };

      return session.copyWith(
        portalToken: handshake.token,
        deviceId: handshake.serial ?? session.deviceId,
        sessionId:
            'stalker_${session.providerId}_${DateTime.now().millisecondsSinceEpoch}',
        expiresAt: DateTime.now().add(_kTokenLifetime),
        cookies: updatedCookies,
      );
    } on StreamAuthException {
      rethrow;
    } catch (e) {
      throw StreamAuthException(
        message: 'Stalker token refresh failed for provider ${session.providerId}.',
        originalError: e,
      );
    } finally {
      await client.dispose();
    }
  }
}
