import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/streaming/errors/stream_exceptions.dart';
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

  void clear() => _factories.clear();
}
