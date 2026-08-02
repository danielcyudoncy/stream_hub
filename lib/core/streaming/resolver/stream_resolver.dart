import 'package:flutter/foundation.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';
import 'package:stream_hub/core/streaming/models/stream_resolution.dart';

/// Options that control how a stream is resolved.
@immutable
class StreamResolutionOptions {
  final bool followRedirects;
  final int maxRedirects;
  final Duration probeTimeout;

  const StreamResolutionOptions({
    this.followRedirects = true,
    this.maxRedirects = 5,
    this.probeTimeout = const Duration(seconds: 10),
  });
}

/// The input to a [StreamResolver]. Combines the provider session with the
/// source URL and item metadata.
@immutable
class StreamResolutionRequest {
  final ProviderSession session;
  final String sourceUrl;
  final String mediaItemId;
  final Map<String, dynamic> itemMetadata;
  final StreamResolutionOptions options;

  const StreamResolutionRequest({
    required this.session,
    required this.sourceUrl,
    required this.mediaItemId,
    this.itemMetadata = const {},
    this.options = const StreamResolutionOptions(),
  });
}

/// Resolves a provider URL into a [StreamResolution].
///
/// Handles relative URL resolution, redirects, stream type/capability
/// detection, quality/format detection, expiration, and DRM discovery.
abstract class StreamResolver {
  Future<StreamResolution> resolve(StreamResolutionRequest request);
}
