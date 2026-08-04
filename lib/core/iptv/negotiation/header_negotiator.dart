import 'package:stream_hub/core/streaming/models/provider_session.dart';
import 'package:stream_hub/core/streaming/network/header_engine.dart';

/// Negotiates the complete HTTP header set for a resolved stream.
///
/// Extends the existing [HeaderEngine] by layering metadata-derived headers
/// (Referer, Origin, explicit custom headers) and any user-supplied IPTV
/// headers on top of the provider session identity headers.
class HeaderNegotiator {
  final HeaderEngine _headerEngine;

  HeaderNegotiator({HeaderEngine? headerEngine})
    : _headerEngine = headerEngine ?? HeaderEngine();

  /// Negotiates headers for a stream backed by [session].
  Map<String, String> negotiate(
    ProviderSession session, {
    Map<String, dynamic> metadata = const {},
    Map<String, String>? customHeaders,
    bool includeAuth = true,
  }) {
    final fromMetadata = <String, String>{
      if (metadata['referer'] != null)
        'Referer': metadata['referer'].toString(),
      if (metadata['origin'] != null) 'Origin': metadata['origin'].toString(),
    };

    final explicitHeaders = <String, String>{};
    final rawHeaders = metadata['headers'];
    if (rawHeaders is Map) {
      rawHeaders.forEach((key, value) {
        explicitHeaders[key.toString()] = value.toString();
      });
    }
    if (customHeaders != null) {
      explicitHeaders.addAll(customHeaders);
    }

    return _headerEngine.fromSession(
      session,
      custom: {...fromMetadata, ...explicitHeaders},
      includeAuth: includeAuth,
    );
  }
}
