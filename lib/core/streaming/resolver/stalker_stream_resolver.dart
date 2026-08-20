import 'dart:async';
import 'dart:io';

import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/enums/stream_type.dart';
import 'package:stream_hub/core/streaming/errors/stream_exceptions.dart';
import 'package:stream_hub/core/streaming/models/stream_capabilities.dart';
import 'package:stream_hub/core/streaming/models/stream_resolution.dart';
import 'package:stream_hub/core/streaming/network/url_normalizer.dart';
import 'package:stream_hub/core/streaming/resolver/stream_resolver.dart';
import 'package:stream_hub/data/providers/stalker/stalker_portal_client.dart';

/// Resolves Stalker Portal media items into playable streams.
///
/// Stalker portals do not expose permanent stream URLs during sync; instead
/// each item stores a `cmd` that must be exchanged for a short-lived playable
/// URL through the `create_link` action (using the current portal token and
/// MAC address). Items that ship a direct source URL (e.g. `direct_source`)
/// bypass the exchange entirely.
class StalkerStreamResolver implements StreamResolver {
  final UrlNormalizer _normalizer;
  final LoggingService _logger;

  StalkerStreamResolver({UrlNormalizer? normalizer, LoggingService? logger})
    : _normalizer = normalizer ?? UrlNormalizer(),
      _logger = logger ?? LoggingService();

  @override
  Future<StreamResolution> resolve(StreamResolutionRequest request) async {
    final session = request.session;
    final metadata = request.itemMetadata;

    final directUrl = _directSourceUrl(metadata);
    if (directUrl != null) {
      _logger.debug(
        'Using direct Stalker stream URL for ${request.mediaItemId}',
        tag: 'StalkerStreamResolver',
      );
      return _resolution(request, directUrl, metadata);
    }

    final cmd = metadata['cmd']?.toString() ??
        (request.sourceUrl.startsWith('stalker://')
            ? request.sourceUrl.substring('stalker://'.length)
            : null);
    if (cmd == null || cmd.isEmpty) {
      throw const StreamResolutionException(
        message: 'Stalker media item has no playable command.',
      );
    }
    final baseUrl = session.baseUrl ??
        metadata['portalUrl']?.toString() ??
        metadata['serverUrl']?.toString();
    if (baseUrl == null || baseUrl.isEmpty) {
      throw const StreamResolutionException(
        message: 'Stalker session is missing the portal URL.',
      );
    }
    final macAddress = session.macAddress ?? metadata['macAddress']?.toString();
    if (macAddress == null || macAddress.isEmpty) {
      throw const StreamResolutionException(
        message: 'Stalker session is missing the MAC address.',
      );
    }

    final client = StalkerPortalClient(
      baseUrl: baseUrl,
      macAddress: macAddress,
      serial: session.deviceId,
      token: session.portalToken,
      logger: _logger,
    );

    try {
      final seriesIdx = metadata['seriesIndex']?.toString() ??
          metadata['episodeNumber']?.toString();
      final url = await client.createLink(
        type: _contentType(metadata),
        cmd: cmd,
        genre: metadata['genreId']?.toString(),
        seriesIndex: seriesIdx,
      );
      return _resolution(request, url, metadata);
    } on StalkerPortalException catch (e) {
      throw StreamResolutionException(
        message: 'Could not resolve the Stalker stream: ${e.message}',
        originalError: e,
      );
    } on SocketException catch (e) {
      throw StreamNetworkException(originalError: e);
    } on TimeoutException catch (e) {
      throw StreamTimeoutException(originalError: e);
    } finally {
      await client.dispose();
    }
  }

  StreamResolution _resolution(
    StreamResolutionRequest request,
    String rawUrl,
    Map<String, dynamic> metadata,
  ) {
    final session = request.session;
    var url = _normalizer.resolveRelative(rawUrl, session.baseUrl ?? '');

    if (!_normalizer.isSupported(url)) {
      throw StreamUnsupportedProtocolException(
        message: 'Unsupported stream protocol: $url',
      );
    }

    url = _normalizer.canonicalize(url);
    final uri = Uri.parse(url);
    final streamType = StreamType.fromUrl(url);
    final isLive = metadata['type']?.toString() == 'live';

    return StreamResolution(
      url: url,
      streamType: streamType,
      expiresAt: session.expiresAt,
      capabilities: isLive
          ? const StreamCapabilities.live()
          : const StreamCapabilities.vod(),
      queryParameters: Map<String, String>.from(uri.queryParameters),
      metadata: Map<String, dynamic>.from(metadata),
    );
  }

  static String? _directSourceUrl(Map<String, dynamic> metadata) {
    for (final key in const ['streamUrl', 'directSource']) {
      final value = metadata[key]?.toString();
      if (value != null && value.isNotEmpty) return value;
    }

    final cmd = metadata['cmd']?.toString();
    if (cmd != null && cmd.isNotEmpty) {
      final clean = cmd
          .replaceFirst(
            RegExp(
              r'^(ffmpeg\s+(-re\s+)?-i\s+|ffmpeg\s+|ffrt\d*\s+|auto\s+)',
              caseSensitive: false,
            ),
            '',
          )
          .trim();
      final uri = Uri.tryParse(clean);
      if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
        final host = uri.host.toLowerCase();
        if (!host.contains('localhost') && !host.contains('127.0.0.1')) {
          if (!clean.contains('stream=&') &&
              !clean.contains('stream=%26') &&
              !clean.endsWith('stream=')) {
            return clean;
          }
        }
      }
    }
    return null;
  }

  static StalkerContentType _contentType(Map<String, dynamic> metadata) {
    final type = metadata['type']?.toString().toLowerCase();
    final mediaType = metadata['mediaType']?.toString().toLowerCase();
    if (type == 'series' ||
        type == 'episode' ||
        mediaType == 'series' ||
        mediaType == 'episode' ||
        metadata.containsKey('seriesIndex') ||
        metadata.containsKey('seasonNumber')) {
      return StalkerContentType.series;
    }
    if (type == 'vod' || mediaType == 'movie') {
      return StalkerContentType.vod;
    }
    return StalkerContentType.live;
  }
}
