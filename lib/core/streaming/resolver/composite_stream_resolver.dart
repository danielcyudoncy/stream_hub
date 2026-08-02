import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/streaming/models/stream_resolution.dart';
import 'package:stream_hub/core/streaming/resolver/stream_resolver.dart';

/// Routes resolution to a provider-specific [StreamResolver] and falls back to
/// a default, provider-agnostic resolver for everything else.
class CompositeStreamResolver implements StreamResolver {
  final StreamResolver _fallback;
  final Map<MediaSourceType, StreamResolver> _resolvers;

  CompositeStreamResolver({
    required StreamResolver fallback,
    Map<MediaSourceType, StreamResolver>? resolvers,
  }) : _fallback = fallback,
       _resolvers = resolvers ?? const {};

  @override
  Future<StreamResolution> resolve(StreamResolutionRequest request) {
    final resolver = _resolvers[request.session.providerType];
    if (resolver != null) {
      return resolver.resolve(request);
    }
    return _fallback.resolve(request);
  }
}
