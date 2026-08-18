import 'dart:async';

import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/enums/stream_type.dart';
import 'package:stream_hub/core/streaming/errors/stream_exceptions.dart';
import 'package:stream_hub/core/streaming/models/stream_capabilities.dart';
import 'package:stream_hub/core/streaming/models/stream_resolution.dart';
import 'package:stream_hub/core/streaming/network/url_normalizer.dart';
import 'package:stream_hub/core/streaming/resolver/stream_resolver.dart';
import 'package:stream_hub/core/streaming/series/xtream_series_info_service.dart';

/// Resolves Xtream Codes media items into playable streams.
///
/// - Live channels and VOD movies carry an authenticated `streamUrl` produced
///   during sync, so they resolve directly.
/// - Series items carry only a `seriesId`. Playback requires an extra
///   `get_series_info` exchange that returns the season/episode structure. When
///   `metadata['episodeId']` is present (for example from the Series Details
///   screen) that exact episode is chosen; otherwise the first playable episode
///   is turned into a `{server}/series/{user}/{pass}/{episodeId}.{ext}` URL.
class XtreamStreamResolver implements StreamResolver {
  final UrlNormalizer _normalizer;
  final LoggingService _logger;
  final XtreamSeriesInfoService _seriesInfoService;

  XtreamStreamResolver({
    UrlNormalizer? normalizer,
    LoggingService? logger,
    XtreamSeriesInfoService? seriesInfoService,
  }) : _normalizer = normalizer ?? UrlNormalizer(),
       _logger = logger ?? LoggingService(),
       _seriesInfoService =
           seriesInfoService ?? XtreamSeriesInfoService(logger: logger);

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

    final seriesId = metadata['seriesId']?.toString() ?? metadata['series_id']?.toString();
    final streamId = metadata['streamId']?.toString() ?? metadata['stream_id']?.toString();

    if (seriesId != null && seriesId.isNotEmpty) {
      final info = await _seriesInfoService.fetch(
        session: session,
        seriesId: seriesId,
        alternativeIds: [
          if (streamId != null && streamId.isNotEmpty) streamId,
        ],
      );

      final requestedEpisodeId = metadata['episodeId']?.toString() ?? metadata['episode_id']?.toString();
      var episode = requestedEpisodeId != null && requestedEpisodeId.isNotEmpty
          ? _findEpisode(info, requestedEpisodeId)
          : null;
      episode ??= info.seasons.expand((s) => s.episodes).firstOrNull;

      if (episode == null) {
        throw const StreamResolutionException(
          message: 'No playable episode found for this series.',
        );
      }

      _logger.debug(
        'Resolved Xtream series episode ${episode.id} for ${request.mediaItemId}',
        tag: 'XtreamStreamResolver',
      );

      final url = episode.streamUrl(
        baseUrl: session.baseUrl,
        username: session.username,
        password: session.password,
      );

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

    if (streamId != null &&
        streamId.isNotEmpty &&
        session.baseUrl != null &&
        session.baseUrl!.isNotEmpty) {
      final isVod = metadata['isVod'] == true ||
          metadata['containerExtension'] != null ||
          metadata['container_extension'] != null;
      final ext = metadata['containerExtension']?.toString() ??
          metadata['container_extension']?.toString() ??
          (isVod ? 'mp4' : 'ts');
      final typeSegment = isVod ? 'movie' : 'live';
      final u = session.username ?? '';
      final p = session.password ?? '';
      final url = '${session.baseUrl}/$typeSegment/$u/$p/$streamId.$ext';
      return _resolution(
        request,
        _normalizer.resolveRelative(url, session.baseUrl ?? ''),
        metadata,
        isVod: isVod,
      );
    }

    throw const StreamResolutionException(
      message: 'Xtream media item has no resolvable stream URL.',
    );
  }

  static XtreamSeriesEpisode? _findEpisode(
    XtreamSeriesInfo info,
    String episodeId,
  ) {
    for (final season in info.seasons) {
      for (final episode in season.episodes) {
        if (episode.id == episodeId) return episode;
      }
    }
    return null;
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
    for (final key in const [
      'streamUrl',
      'stream_url',
      'url',
      'directSource',
      'direct_source',
    ]) {
      final value = metadata[key]?.toString();
      if (value != null &&
          value.isNotEmpty &&
          !value.startsWith('series://') &&
          !value.startsWith('stalker://')) {
        return value;
      }
    }
    return null;
  }
}
