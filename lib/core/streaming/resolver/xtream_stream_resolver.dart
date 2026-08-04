import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/enums/stream_type.dart';
import 'package:stream_hub/core/network/doh_http_client.dart';
import 'package:stream_hub/core/streaming/errors/stream_exceptions.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';
import 'package:stream_hub/core/streaming/models/stream_capabilities.dart';
import 'package:stream_hub/core/streaming/models/stream_resolution.dart';
import 'package:stream_hub/core/streaming/network/url_normalizer.dart';
import 'package:stream_hub/core/streaming/resolver/stream_resolver.dart';

/// Resolves Xtream Codes media items into playable streams.
///
/// - Live channels and VOD movies carry an authenticated `streamUrl` produced
///   during sync, so they resolve directly.
/// - Series items carry only a `seriesId`. Playback requires an extra
///   `get_series_info` exchange that returns the season/episode structure; the
///   first playable episode is chosen and turned into a
///   `{server}/series/{user}/{pass}/{episodeId}.{ext}` URL.
class XtreamStreamResolver implements StreamResolver {
  static const Duration _kRequestTimeout = Duration(seconds: 15);

  final UrlNormalizer _normalizer;
  final LoggingService _logger;
  final HttpClient _client = createDohAwareHttpClient();

  XtreamStreamResolver({UrlNormalizer? normalizer, LoggingService? logger})
    : _normalizer = normalizer ?? UrlNormalizer(),
      _logger = logger ?? LoggingService();

  @override
  Future<StreamResolution> resolve(StreamResolutionRequest request) async {
    final session = request.session;
    final metadata = request.itemMetadata;

    final directUrl = _directSourceUrl(metadata);
    if (directUrl != null && directUrl.isNotEmpty) {
      return _resolution(
        request,
        _normalizer.resolveRelative(directUrl, session.baseUrl ?? ''),
        metadata,
        isVod: metadata['isVod'] == true,
      );
    }

    final seriesId = metadata['seriesId']?.toString();
    if (seriesId == null || seriesId.isEmpty) {
      throw const StreamResolutionException(
        message: 'Xtream media item has no resolvable stream URL.',
      );
    }

    final episode = await _resolveFirstEpisode(session, seriesId);
    if (episode == null) {
      throw const StreamResolutionException(
        message: 'No playable episode found for this series.',
      );
    }

    _logger.debug(
      'Resolved Xtream series episode ${episode.id} for ${request.mediaItemId}',
      tag: 'XtreamStreamResolver',
    );

    final url = '${session.baseUrl}/series'
        '/${session.username ?? ''}/${session.password ?? ''}'
        '/${episode.id}.${episode.extension}';

    return _resolution(
      request,
      _normalizer.resolveRelative(url, session.baseUrl ?? ''),
      {
        ...metadata,
        'episodeId': episode.id,
        'episodeTitle': episode.title,
      },
      isVod: true,
    );
  }

  Future<XtreamEpisode?> _resolveFirstEpisode(
    ProviderSession session,
    String seriesId,
  ) async {
    final baseUrl = session.baseUrl;
    if (baseUrl == null || baseUrl.isEmpty) {
      throw const StreamResolutionException(
        message: 'Xtream session is missing the server URL.',
      );
    }

    final uri = Uri.parse(
      '$baseUrl/player_api.php'
      '?username=${session.username ?? ''}'
      '&password=${session.password ?? ''}'
      '&action=get_series_info&series_id=$seriesId',
    );

    String body;
    try {
      final request = await _client.getUrl(uri).timeout(_kRequestTimeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.userAgentHeader, 'StreamHubPro/1.0');
      final response = await request.close().timeout(_kRequestTimeout);
      if (response.statusCode != 200) {
        throw StreamResolutionException(
          message:
              'Xtream API returned ${response.statusCode} while resolving '
              'series $seriesId.',
        );
      }
      final bytes = await response.fold<List<int>>(
        [],
        (prev, chunk) => prev..addAll(chunk),
      );
      body = utf8.decode(bytes);
    } on SocketException catch (e) {
      throw StreamNetworkException(originalError: e);
    } on TimeoutException catch (e) {
      throw StreamTimeoutException(originalError: e);
    }

    try {
      final decoded = json.decode(body);
      if (decoded is! Map<String, dynamic>) return null;
      return _firstEpisodeFrom(decoded);
    } catch (e) {
      _logger.warning(
        'Xtream get_series_info returned malformed JSON for $seriesId',
        tag: 'XtreamStreamResolver',
        error: e,
      );
      return null;
    }
  }

  /// Extracts the first playable episode from a `get_series_info` payload.
  ///
  /// Handles both layouts used by panels:
  /// - `seasons: [{ episodes: [...] }]`
  /// - `episodes: { "1": [...], "2": [...] }`
  XtreamEpisode? _firstEpisodeFrom(Map<String, dynamic> decoded) {
    final episodes = <XtreamEpisode>[];

    final seasons = decoded['seasons'];
    if (seasons is List) {
      for (final season in seasons) {
        if (season is! Map) continue;
        final seasonEpisodes = season['episodes'];
        if (seasonEpisodes is List) {
          for (final episode in seasonEpisodes) {
            final parsed = _parseEpisode(episode);
            if (parsed != null) episodes.add(parsed);
          }
        }
      }
    }

    final episodesMap = decoded['episodes'];
    if (episodesMap is Map) {
      for (final seasonList in episodesMap.values) {
        if (seasonList is! List) continue;
        for (final episode in seasonList) {
          final parsed = _parseEpisode(episode);
          if (parsed != null) episodes.add(parsed);
        }
      }
    }

    episodes.sort((a, b) => (a.seasonNum.compareTo(b.seasonNum)) != 0
        ? a.seasonNum.compareTo(b.seasonNum)
        : a.episodeNum.compareTo(b.episodeNum));

    if (episodes.isEmpty) return null;
    return episodes.first;
  }

  XtreamEpisode? _parseEpisode(dynamic raw) {
    if (raw is! Map) return null;
    final id = raw['id']?.toString();
    if (id == null || id.isEmpty) return null;

    final ext = (raw['container_extension'] as String? ?? '')
        .trim()
        .toLowerCase()
        .replaceFirst('.', '');
    return XtreamEpisode(
      id: id,
      title: raw['title'] as String? ?? 'Episode $id',
      extension: ext.isEmpty ? 'mkv' : ext,
      seasonNum: _toInt(raw['season']),
      episodeNum: _toInt(raw['episode_num']),
    );
  }

  StreamResolution _resolution(
    StreamResolutionRequest request,
    String rawUrl,
    Map<String, dynamic> metadata, {
    required bool isVod,
  }) {
    final session = request.session;
    var url = rawUrl;

    if (!_normalizer.isSupported(url)) {
      throw StreamUnsupportedProtocolException(
        message: 'Unsupported stream protocol: $url',
      );
    }

    url = _normalizer.canonicalize(url);
    final uri = Uri.parse(url);
    final streamType = StreamType.fromUrl(url);

    return StreamResolution(
      url: url,
      streamType: streamType,
      expiresAt: session.expiresAt,
      capabilities: isVod
          ? const StreamCapabilities.vod()
          : const StreamCapabilities.live(),
      queryParameters: Map<String, String>.from(uri.queryParameters),
      metadata: Map<String, dynamic>.from(metadata),
    );
  }

  static String? _directSourceUrl(Map<String, dynamic> metadata) {
    for (final key in const ['streamUrl', 'directSource']) {
      final value = metadata[key]?.toString();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static int _toInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw) ?? 0;
    if (raw is num) return raw.toInt();
    return 0;
  }
}

/// A single playable episode discovered through `get_series_info`.
class XtreamEpisode {
  final String id;
  final String title;
  final String extension;
  final int seasonNum;
  final int episodeNum;

  const XtreamEpisode({
    required this.id,
    required this.title,
    required this.extension,
    this.seasonNum = 0,
    this.episodeNum = 0,
  });
}
