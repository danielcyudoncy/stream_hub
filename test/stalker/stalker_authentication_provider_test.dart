import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/streaming/auth/providers/stalker_authentication_provider.dart';
import 'package:stream_hub/core/streaming/errors/stream_exceptions.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';

import 'portal_test_server.dart';

void main() {
  group('StalkerAuthenticationProvider', () {
    test('refresh performs a real handshake and renews the token', () async {
      final server = await PortalTestServer.start(handler: defaultHandler);
      addTearDown(server.close);

      final provider = StalkerAuthenticationProvider(logger: LoggingService());
      final session = ProviderSession(
        providerId: 'p1',
        providerType: MediaSourceType.stalker,
        sessionId: 'old-session',
        baseUrl: server.baseUrl,
        macAddress: 'AA:BB:CC:DD:EE:FF',
        portalToken: 'expired-token',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );

      final refreshed = await provider.refresh(session);

      expect(refreshed.portalToken, 'tok-abc-123');
      expect(refreshed.sessionId, isNot('old-session'));
      expect(refreshed.isExpired, isFalse);
      expect(refreshed.deviceId, 'sn-001');
    });

    test('refresh throws StreamAuthException without a portal URL', () async {
      final provider = StalkerAuthenticationProvider(logger: LoggingService());
      final session = ProviderSession(
        providerId: 'p1',
        providerType: MediaSourceType.stalker,
        sessionId: 's1',
        macAddress: 'AA:BB:CC:DD:EE:FF',
      );

      expect(
        provider.refresh(session),
        throwsA(isA<StreamAuthException>()),
      );
    });

    test('validate requires a MAC address and a fresh token', () async {
      final provider = StalkerAuthenticationProvider(logger: LoggingService());

      final missingMac = ProviderSession(
        providerId: 'p1',
        providerType: MediaSourceType.stalker,
        sessionId: 's1',
        portalToken: 'tok',
      );
      final missingMacResult = await provider.validate(missingMac);
      expect(missingMacResult.isAuthenticated, isFalse);

      final valid = ProviderSession(
        providerId: 'p1',
        providerType: MediaSourceType.stalker,
        sessionId: 's1',
        macAddress: 'AA:BB:CC:DD:EE:FF',
        portalToken: 'tok',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      final validResult = await provider.validate(valid);
      expect(validResult.isAuthenticated, isTrue);
    });
  });
}
