import 'package:stream_hub/core/iptv/models/playlist_analysis.dart';
import 'package:stream_hub/core/iptv/models/provider_detection.dart';
import 'package:stream_hub/core/iptv/models/stream_protocol.dart';
import 'package:stream_hub/data/models/m3u_models.dart';
import 'package:stream_hub/data/parsers/m3u_parser.dart';

/// Analyzes an M3U/IPLAY playlist and extracts groups, channels, movies,
/// series, radio, catch-up, timeshift, headers, user agent, EPG references,
/// TVG information, custom attributes, and protocol distribution.
///
/// Reuses the existing [M3UParser] for structural parsing and layers provider
/// classification and header metadata extraction on top for diagnostics.
class PlaylistAnalyzer {
  final M3UParser _parser;

  PlaylistAnalyzer({M3UParser? parser}) : _parser = parser ?? M3UParser();

  /// Analyzes playlist [content]. [sourceUrl] is used only for reporting.
  PlaylistAnalysis analyze(
    String content, {
    String? sourceUrl,
    DetectedProviderKind? providerKind,
  }) {
    final stopwatch = Stopwatch()..start();
    final analyzedAt = DateTime.now();
    final errors = <String>[];
    final warnings = <String>[];

    if (content.trim().isEmpty) {
      errors.add('Playlist content is empty.');
      return PlaylistAnalysis(
        providerKind: providerKind ?? DetectedProviderKind.m3u,
        errors: errors,
        warnings: warnings,
        stats: PlaylistStats(hasValidHeader: false),
        analyzedAt: analyzedAt,
      );
    }

    final parsed = _parser.parse(content);
    warnings.addAll(parsed.warnings);
    if (!parsed.hasValidHeader) {
      warnings.add('Missing #EXTM3U header (treated as warning).');
    }

    final headerAttrs = _extractHeaderAttributes(content);
    final epgSources = _extractEpgSources(headerAttrs);
    final userAgent = _extractUserAgent(headerAttrs);
    final referer = _extractReferer(headerAttrs);
    final headers = _extractHeaders(headerAttrs, userAgent, referer);
    final tvgInfo = _extractTvgInfo(headerAttrs, epgSources);

    final items = <PlaylistItem>[];
    final groups = <String>{...parsed.groups};
    final protocolCounts = <String, int>{};
    var movies = 0;
    var series = 0;
    var radio = 0;
    var channels = 0;
    var hasCatchup = false;
    var hasTimeshift = false;

    for (final channel in parsed.channels) {
      final isMovie = _isMovie(channel);
      final isSeries = _isSeries(channel);
      final isRadio = channel.isRadio;

      if (isMovie) {
        movies++;
      } else if (isSeries) {
        series++;
      } else if (isRadio) {
        radio++;
      } else {
        channels++;
      }

      final catchup = channel.catchup;
      if (catchup.isNotEmpty) hasCatchup = true;
      if (catchup['timeshift'] == 'true' ||
          catchup.containsKey('timeshift') ||
          channel.attributes.containsKey('timeshift')) {
        hasTimeshift = true;
      }

      final url = channel.streamUrl ?? '';
      if (url.isNotEmpty) {
        final protocol = StreamProtocol.fromUrl(url);
        protocolCounts.update(
          protocol.displayName,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }

      items.add(
        PlaylistItem(
          title: channel.title,
          url: url,
          group: channel.group,
          tvgId: channel.tvgId,
          tvgName: channel.tvgName,
          logo: channel.logo,
          isRadio: isRadio,
          isMovie: isMovie,
          isSeries: isSeries,
          catchup: channel.catchup,
          attributes: channel.attributes,
          warnings: channel.warnings,
        ),
      );
    }

    stopwatch.stop();
    return PlaylistAnalysis(
      providerKind: providerKind ?? DetectedProviderKind.m3u,
      items: items,
      groups: groups.toList()..sort(),
      channelCount: channels,
      movieCount: movies,
      seriesCount: series,
      radioCount: radio,
      hasCatchup: hasCatchup,
      hasTimeshift: hasTimeshift,
      headers: headers,
      userAgent: userAgent,
      referer: referer,
      epgSources: epgSources,
      tvgInfo: tvgInfo,
      customAttributes: _extractCustomAttributes(headerAttrs),
      errors: errors,
      warnings: warnings,
      stats: PlaylistStats(
        totalEntries: parsed.totalEntries,
        validEntries: parsed.validEntries,
        invalidEntries: parsed.invalidEntries,
        duplicateUrls: parsed.duplicateEntries,
        encoding: parsed.encoding,
        hasValidHeader: parsed.hasValidHeader,
        analysisDuration: stopwatch.elapsed,
      ),
      protocolDistribution: protocolCounts,
      analyzedAt: analyzedAt,
    );
  }

  bool _isMovie(M3UChannel channel) {
    final group = (channel.group ?? '').toLowerCase();
    final type = (channel.attributes['tvg-type'] ??
            channel.attributes['channel-type'] ??
            '')
        .toLowerCase();
    final url = (channel.streamUrl ?? '').toLowerCase();
    return type.contains('movie') ||
        type.contains('vod') ||
        group.contains('movie') ||
        group.contains('film') ||
        group.contains('vod') ||
        url.contains('/movie/');
  }

  bool _isSeries(M3UChannel channel) {
    final group = (channel.group ?? '').toLowerCase();
    final type = (channel.attributes['tvg-type'] ??
            channel.attributes['channel-type'] ??
            '')
        .toLowerCase();
    final url = (channel.streamUrl ?? '').toLowerCase();
    return type.contains('series') ||
        group.contains('series') ||
        group.contains('season') ||
        group.contains('shows') ||
        url.contains('/series/');
  }

  /// Parses `#EXTM3U` header attributes (e.g. `x-tvg-url`, `user-agent`).
  Map<String, String> _extractHeaderAttributes(String content) {
    final attrs = <String, String>{};
    final firstLine = content.trimLeft().split('\n').first.trim();
    if (!firstLine.startsWith('#EXTM3U')) return attrs;
    final attrPart = firstLine.substring('#EXTM3U'.length).trim();
    if (attrPart.isEmpty) return attrs;

    final quoted = RegExp(r'([a-zA-Z0-9\-_]+)="([^"]*)"');
    for (final match in quoted.allMatches(attrPart)) {
      final key = match.group(1)?.toLowerCase().trim();
      final value = match.group(2) ?? '';
      if (key != null && key.isNotEmpty && !attrs.containsKey(key)) {
        attrs[key] = value;
      }
    }
    final unquoted = RegExp(r'([a-zA-Z0-9\-_]+)=([^\s,]+)');
    for (final match in unquoted.allMatches(attrPart)) {
      final key = match.group(1)?.toLowerCase().trim();
      final value = match.group(2) ?? '';
      if (key != null && key.isNotEmpty && !attrs.containsKey(key)) {
        attrs[key] = value;
      }
    }
    return attrs;
  }

  List<String> _extractEpgSources(Map<String, String> headerAttrs) {
    final sources = <String>[];
    for (final entry in headerAttrs.entries) {
      final key = entry.key;
      if (key == 'x-tvg-url' ||
          key == 'tvg-url' ||
          key == 'url-tvg' ||
          key.startsWith('url-tvg-')) {
        final value = entry.value.trim();
        if (value.isNotEmpty && !sources.contains(value)) {
          sources.add(value);
        }
      }
    }
    return sources;
  }

  String? _extractUserAgent(Map<String, String> headerAttrs) {
    for (final key in const [
      'user-agent',
      'http-user-agent',
      'http_user_agent',
    ]) {
      final value = headerAttrs[key];
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  String? _extractReferer(Map<String, String> headerAttrs) {
    for (final key in const ['referer', 'http-referer', 'http_referer']) {
      final value = headerAttrs[key];
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  Map<String, String> _extractHeaders(
    Map<String, String> headerAttrs,
    String? userAgent,
    String? referer,
  ) {
    final headers = <String, String>{};
    final origin = headerAttrs['origin'] ?? headerAttrs['http-origin'];
    if (origin != null && origin.isNotEmpty) headers['Origin'] = origin;
    if (userAgent != null && userAgent.isNotEmpty) {
      headers['User-Agent'] = userAgent;
    }
    if (referer != null && referer.isNotEmpty) headers['Referer'] = referer;
    for (final entry in headerAttrs.entries) {
      if (entry.key.startsWith('header-') ||
          entry.key.startsWith('http-header-')) {
        final name = entry.key
            .replaceFirst('header-', '')
            .replaceFirst('http-header-', '');
        if (name.isNotEmpty) {
          headers[name.replaceFirst(name[0], name[0].toUpperCase())] =
              entry.value;
        }
      }
    }
    return headers;
  }

  Map<String, String> _extractTvgInfo(
    Map<String, String> headerAttrs,
    List<String> epgSources,
  ) {
    final tvgInfo = <String, String>{};
    for (final entry in headerAttrs.entries) {
      if (entry.key.startsWith('tvg-') && !epgSources.contains(entry.value)) {
        tvgInfo[entry.key] = entry.value;
      }
    }
    return tvgInfo;
  }

  Map<String, String> _extractCustomAttributes(Map<String, String> headerAttrs) {
    final known = <String>{
      'x-tvg-url',
      'tvg-url',
      'user-agent',
      'http-user-agent',
      'http_user_agent',
      'referer',
      'http-referer',
      'http_referer',
      'origin',
      'http-origin',
      'charset',
      'cache',
      'refresh',
    };
    final custom = <String, String>{};
    for (final entry in headerAttrs.entries) {
      if (!known.contains(entry.key)) {
        custom[entry.key] = entry.value;
      }
    }
    return custom;
  }
}
