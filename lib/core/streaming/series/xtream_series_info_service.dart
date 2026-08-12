import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/network/doh_http_client.dart';
import 'package:stream_hub/core/streaming/errors/stream_exceptions.dart';
import 'package:stream_hub/core/streaming/models/provider_session.dart';

/// A single playable episode discovered through `get_series_info`.
class XtreamSeriesEpisode {
  final String id;
  final String title;
  final String extension;
  final int seasonNum;
  final int episodeNum;
  final String? plot;
  final String? cover;
  final int? durationSeconds;
  final String? airDate;

  const XtreamSeriesEpisode({
    required this.id,
    required this.title,
    required this.extension,
    this.seasonNum = 0,
    this.episodeNum = 0,
    this.plot,
    this.cover,
    this.durationSeconds,
    this.airDate,
  });

  /// Builds the authenticated stream URL for this episode. Xtream serves
  /// series episodes from `{server}/series/{user}/{pass}/{episodeId}.{ext}`.
  String streamUrl({
    required String? baseUrl,
    required String? username,
    required String? password,
  }) {
    return '$baseUrl/series/$username/$password/$id.$extension';
  }
}

/// A season group parsed from `get_series_info`.
class XtreamSeriesSeason {
  final int number;
  final String name;
  final List<XtreamSeriesEpisode> episodes;

  const XtreamSeriesSeason({
    required this.number,
    required this.name,
    required this.episodes,
  });
}

/// The parsed `get_series_info` payload for a series.
class XtreamSeriesInfo {
  final String seriesId;
  final String name;
  final String cover;
  final String backdrop;
  final List<XtreamSeriesSeason> seasons;

  const XtreamSeriesInfo({
    required this.seriesId,
    required this.name,
    this.cover = '',
    this.backdrop = '',
    required this.seasons,
  });

  int get seasonCount => seasons.length;

  int get totalEpisodes =>
      seasons.fold(0, (sum, season) => sum + season.episodes.length);
}

/// Fetches and parses Xtream Codes `get_series_info` payloads.
///
/// This is the single source of truth for discovering a series' seasons and
/// episodes. Both the [XtreamStreamResolver] (during playback) and the Series
/// Details screen consume it, so episode discovery behaves identically
/// everywhere.
class XtreamSeriesInfoService {
  static const Duration _kRequestTimeout = Duration(seconds: 15);

  final LoggingService _logger;
  final HttpClient _client;

  XtreamSeriesInfoService({LoggingService? logger, HttpClient? client})
    : _logger = logger ?? LoggingService(),
      _client = client ?? createDohAwareHttpClient();

  /// Fetches and parses the season/episode structure for [seriesId].
  ///
  /// Some panels index `get_series_info` by the stream ID rather than the
  /// series ID (or vice versa), so [alternativeIds] are tried in order when the
  /// primary ID is rejected with HTTP 404. If every candidate 404s the panel
  /// does not implement series info; a
  /// [StreamSeriesInfoUnavailableException] is thrown so callers can degrade
  /// gracefully.
  ///
  /// Throws [StreamResolutionException] for malformed responses,
  /// [StreamNetworkException] on socket failures, and
  /// [StreamTimeoutException] on timeouts.
  Future<XtreamSeriesInfo> fetch({
    required ProviderSession session,
    required String seriesId,
    List<String> alternativeIds = const [],
  }) async {
    final baseUrl = session.baseUrl;
    if (baseUrl == null || baseUrl.isEmpty) {
      throw const StreamResolutionException(
        message: 'Xtream session is missing the server URL.',
      );
    }

    // A few panels index series info under the stream ID (or a numeric-only
    // variant of the series ID) rather than the raw series ID, so every known
    // alias is tried in order before giving up.
    final seen = <String>{};
    final candidates = <String>[
      seriesId,
      _numericOnly(seriesId),
      ...alternativeIds,
      ...alternativeIds.map(_numericOnly),
    ];
    for (final id in candidates) {
      if (id.isEmpty || !seen.add(id)) continue;
      final info = await _fetchForId(
        baseUrl: baseUrl,
        session: session,
        seriesId: id,
      );
      if (info != null) return info;
    }

    throw const StreamSeriesInfoUnavailableException(
      message: 'This provider does not expose an episode list for the series.',
    );
  }

  /// Returns the parsed series info for [seriesId], or `null` when the panel
  /// answers HTTP 404 (meaning it does not know the id / action).
  Future<XtreamSeriesInfo?> _fetchForId({
    required String baseUrl,
    required ProviderSession session,
    required String seriesId,
  }) async {
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
      if (response.statusCode == HttpStatus.notFound) return null;
      if (response.statusCode != HttpStatus.ok) {
        throw StreamResolutionException(
          message:
              'Xtream API returned ${response.statusCode} while fetching '
              'series $seriesId info.',
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

    // Panels that do not implement the action sometimes answer HTTP 200 with
    // an empty body (or a bare `[]` / `null`) instead of 404. Treat those as
    // "no info for this id" so the next candidate is tried and callers degrade
    // gracefully instead of hard-failing.
    if (body.trim().isEmpty) return null;

    final Object? decoded;
    try {
      decoded = json.decode(body);
    } catch (e) {
      _logger.warning(
        'Xtream get_series_info returned malformed JSON for $seriesId',
        tag: 'XtreamSeriesInfoService',
        error: e,
      );
      throw StreamResolutionException(
        message: 'Xtream get_series_info returned an invalid payload for '
            'series $seriesId.',
        originalError: e,
      );
    }

    if (decoded is! Map<String, dynamic>) return null;

    // A few panels wrap the payload in a `data` object.
    final wrapped = decoded['data'];
    final Map<String, dynamic> root =
        wrapped is Map ? Map<String, dynamic>.from(wrapped) : decoded;
    return _parse(root, seriesId);
  }

  /// Parses a `get_series_info` payload, handling the layouts used by
  /// different panels:
  /// - `seasons: [{ id, season_number, name, episodes: [...] | {...} }]`
  /// - `seasons: { "1": { name, episodes: [...] }, ... }` (keyed by season)
  /// - `episodes: { "1": [...], "2": [...] }`
  /// - `episodes: [{ season, episode_num, ... }, ...]` (flat list)
  XtreamSeriesInfo _parse(Map<String, dynamic> decoded, String seriesId) {
    final seasonNames = <int, String>{};
    final episodes = <XtreamSeriesEpisode>[];

    _parseSeasonList(decoded['seasons'], seasonNames, episodes);
    _parseSeasonMap(decoded['seasons'], seasonNames, episodes);
    _parseTopLevelEpisodes(decoded['episodes'], episodes);

    episodes.sort((a, b) {
      final seasonComparison = a.seasonNum.compareTo(b.seasonNum);
      return seasonComparison != 0
          ? seasonComparison
          : a.episodeNum.compareTo(b.episodeNum);
    });

    final grouped = <int, List<XtreamSeriesEpisode>>{};
    for (final episode in episodes) {
      grouped.putIfAbsent(episode.seasonNum, () => []).add(episode);
    }
    final seasonNumbers = grouped.keys.toList()..sort();

    final seasonList = seasonNumbers.map((number) {
      return XtreamSeriesSeason(
        number: number,
        name: seasonNames[number] ?? 'Season $number',
        episodes: grouped[number]!,
      );
    }).toList();

    return XtreamSeriesInfo(
      seriesId: seriesId,
      name: _stringValue(decoded['name']),
      cover: _stringValue(decoded['cover']),
      backdrop: _stringValue(decoded['backdrop_path']),
      seasons: seasonList,
    );
  }

  /// Parses `seasons` emitted as a list
  /// (`[{ id, season_number, name, episodes }]`).
  void _parseSeasonList(
    dynamic raw,
    Map<int, String> seasonNames,
    List<XtreamSeriesEpisode> out,
  ) {
    if (raw is! List) return;
    for (final season in raw) {
      if (season is! Map) continue;
      final seasonNumber = _seasonNumber(season);
      final seasonName = _stringValue(season['name']).trim();
      if (seasonNumber > 0 && seasonName.isNotEmpty) {
        seasonNames[seasonNumber] = seasonName;
      }
      _parseEpisodes(season['episodes'], seasonNumber, out);
    }
  }

  /// Parses `seasons` emitted as a map keyed by season number
  /// (`{ "1": { name, episodes }, ... }`).
  void _parseSeasonMap(
    dynamic raw,
    Map<int, String> seasonNames,
    List<XtreamSeriesEpisode> out,
  ) {
    if (raw is! Map) return;
    for (final entry in raw.entries) {
      final season = entry.value;
      if (season is! Map) continue;
      // The value may not carry an id, in which case the map key is the
      // season number.
      final seasonNumber = _seasonNumber(season);
      final resolved = seasonNumber > 0 ? seasonNumber : _toInt(entry.key);
      if (resolved <= 0) continue;
      final seasonName = _stringValue(season['name']).trim();
      if (seasonName.isNotEmpty) {
        seasonNames[resolved] = seasonName;
      }
      _parseEpisodes(season['episodes'], resolved, out);
    }
  }

  /// Parses the top-level `episodes` field: a map keyed by season number
  /// (`{"1": [...]}`) or a flat list whose episodes carry their own `season`.
  void _parseTopLevelEpisodes(dynamic raw, List<XtreamSeriesEpisode> out) {
    if (raw is Map) {
      for (final entry in raw.entries) {
        _parseEpisodes(entry.value, _toInt(entry.key), out);
      }
    } else if (raw is List) {
      for (final episode in raw) {
        final parsed = _parseEpisode(episode, fallbackSeason: 0);
        if (parsed != null) out.add(parsed);
      }
    }
  }

  /// Parses an episode container that is either a list or a map keyed by
  /// episode number.
  void _parseEpisodes(
    dynamic raw,
    int fallbackSeason,
    List<XtreamSeriesEpisode> out,
  ) {
    if (raw is List) {
      for (final episode in raw) {
        final parsed = _parseEpisode(episode, fallbackSeason: fallbackSeason);
        if (parsed != null) out.add(parsed);
      }
    } else if (raw is Map) {
      for (final entry in raw.entries) {
        final parsed = _parseEpisode(entry.value, fallbackSeason: fallbackSeason);
        if (parsed != null) out.add(parsed);
      }
    }
  }

  /// Extracts the season number from a season map, trying the standard field
  /// names used by different panels (`season_number`, `id`, `seasonNumber`).
  static int _seasonNumber(Map season) {
    for (final key in const ['season_number', 'id', 'seasonNumber']) {
      final number = _toInt(season[key]);
      if (number > 0) return number;
    }
    return 0;
  }

  XtreamSeriesEpisode? _parseEpisode(
    dynamic raw, {
    int fallbackSeason = 0,
  }) {
    if (raw is! Map) return null;
    final id = raw['id']?.toString();
    if (id == null || id.isEmpty) return null;

    final ext = (raw['container_extension'] as String? ?? '')
        .trim()
        .toLowerCase()
        .replaceFirst('.', '');
    final season = _toInt(raw['season']);
    final episodeNum = _toInt(raw['episode_num']);

    return XtreamSeriesEpisode(
      id: id,
      title: raw['title'] as String? ?? 'Episode ${episodeNum == 0 ? id : episodeNum}',
      extension: ext.isEmpty ? 'mkv' : ext,
      seasonNum: season != 0 ? season : fallbackSeason,
      episodeNum: episodeNum,
      plot: _plotFrom(raw),
      cover: _coverFrom(raw),
      durationSeconds: _durationFrom(raw['duration']),
      airDate: (raw['air_date'] as String?) ?? (raw['airdate'] as String?),
    );
  }

  static String? _plotFrom(Map raw) {
    final direct = (raw['plot'] as String?) ?? (raw['description'] as String?);
    if (direct != null && direct.isNotEmpty) return direct;
    final info = raw['info'];
    if (info is Map) {
      final plot = info['plot'];
      if (plot is String && plot.isNotEmpty) return plot;
    }
    return null;
  }

  static String? _coverFrom(Map raw) {
    final direct = (raw['cover'] as String?) ?? (raw['movie_image'] as String?);
    if (direct != null && direct.isNotEmpty) return direct;
    final info = raw['info'];
    if (info is Map) {
      final image = info['movie_image'];
      if (image is String && image.isNotEmpty) return image;
    }
    return null;
  }

  /// Parses episode duration in seconds from either an integer or an
  /// `HH:MM:SS` / plain-number string (both are emitted by panels).
  static int? _durationFrom(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      final timeMatch = RegExp(
        r'^(\d+):(\d{1,2}):(\d{1,2})$',
      ).firstMatch(trimmed);
      if (timeMatch != null) {
        final hours = int.parse(timeMatch.group(1)!);
        final minutes = int.parse(timeMatch.group(2)!);
        final seconds = int.parse(timeMatch.group(3)!);
        return hours * 3600 + minutes * 60 + seconds;
      }
      return int.tryParse(trimmed);
    }
    return null;
  }

  static String _stringValue(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }

  static int _toInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw) ?? 0;
    if (raw is num) return raw.toInt();
    return 0;
  }

  /// Reduces an id to its numeric digits. Some panels mangle series ids (e.g.
  /// `S-37354`) but still index `get_series_info` by the bare number.
  static String _numericOnly(String id) {
    return id.replaceAll(RegExp(r'[^0-9]'), '');
  }
}
