import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/streaming/errors/stream_exceptions.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';
import 'package:stream_hub/core/streaming/session/provider_session_factory.dart';
import 'package:stream_hub/core/streaming/session/provider_session_factory_registry.dart';

class _FakeFactory implements ProviderSessionFactory {
  final MediaSourceType type;
  _FakeFactory(this.type);

  @override
  MediaSourceType get providerType => type;

  @override
  Future<ProviderSession> createSession({
    required String mediaItemId,
    required Map<String, dynamic> itemMetadata,
    Map<String, dynamic>? providerConfig,
    ProviderSession? existing,
  }) async {
    return ProviderSession(
      providerId: mediaItemId,
      providerType: type,
      sessionId: 'session-$mediaItemId',
    );
  }
}

void main() {
  group('ProviderSessionFactoryRegistry', () {
    late ProviderSessionFactoryRegistry registry;

    setUp(() {
      registry = ProviderSessionFactoryRegistry();
    });

    test('register and lookup by provider type', () {
      final factory = _FakeFactory(MediaSourceType.m3u);
      registry.register(factory);
      expect(registry.factoryFor(MediaSourceType.m3u), same(factory));
      expect(registry.require(MediaSourceType.m3u), same(factory));
    });

    test('require throws for unregistered types', () {
      expect(
        () => registry.require(MediaSourceType.xtream),
        throwsA(isA<StreamInvalidSessionException>()),
      );
    });

    test('factoryFor returns null for unregistered types', () {
      expect(registry.factoryFor(MediaSourceType.stalker), isNull);
    });

    test('all returns registered factories', () {
      final m3u = _FakeFactory(MediaSourceType.m3u);
      final xtream = _FakeFactory(MediaSourceType.xtream);
      registry.register(m3u);
      registry.register(xtream);
      expect(registry.all, containsAll([m3u, xtream]));
    });

    test('clear empties the registry', () {
      registry.register(_FakeFactory(MediaSourceType.m3u));
      registry.clear();
      expect(registry.all, isEmpty);
      expect(registry.factoryFor(MediaSourceType.m3u), isNull);
    });
  });
}
