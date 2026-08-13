import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/streaming/errors/stream_exceptions.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';
import 'package:stream_hub/core/streaming/session/provider_session_factory.dart';

/// Registry that maps every [MediaSourceType] to its [ProviderSessionFactory].
///
/// The Stream Engine asks the registry for the adapter of the current provider
/// type, so adding a new provider never requires changes to the engine, player,
/// or download engine.
class ProviderSessionFactoryRegistry {
  final Map<MediaSourceType, ProviderSessionFactory> _factories = {};

  void register(ProviderSessionFactory factory) {
    _factories[factory.providerType] = factory;
  }

  ProviderSessionFactory? factoryFor(MediaSourceType type) {
    return _factories[type];
  }

  ProviderSessionFactory require(MediaSourceType type) {
    final factory = _factories[type];
    if (factory == null) {
      throw StreamInvalidSessionException(
        message: 'No provider session factory registered for ${type.name}.',
      );
    }
    return factory;
  }

  List<ProviderSessionFactory> get all => _factories.values.toList();

  /// Creates a session by first trying the exact [type] match, then falling
  /// back to every registered factory in registration order until one
  /// succeeds. This makes playback resilient when an item's
  /// [MediaSourceType] is missing or does not have a dedicated factory.
  Future<ProviderSession> createSession({
    required MediaSourceType type,
    required String mediaItemId,
    required Map<String, dynamic> itemMetadata,
    Map<String, dynamic>? providerConfig,
    ProviderSession? existing,
  }) async {
    final exact = _factories[type];

    if (exact != null) {
      return exact.createSession(
        mediaItemId: mediaItemId,
        itemMetadata: itemMetadata,
        providerConfig: providerConfig,
        existing: existing,
      );
    }

    for (final factory in _factories.values) {
      try {
        return await factory.createSession(
          mediaItemId: mediaItemId,
          itemMetadata: itemMetadata,
          providerConfig: providerConfig,
          existing: existing,
        );
      } on StreamEngineException {
        rethrow;
      } catch (_) {
        continue;
      }
    }

    throw StreamInvalidSessionException(
      message: 'No provider session factory registered for $type.',
    );
  }

  void clear() => _factories.clear();
}
