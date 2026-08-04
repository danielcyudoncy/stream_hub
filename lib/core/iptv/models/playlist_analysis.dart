import 'package:flutter/foundation.dart';
import 'package:stream_hub/core/iptv/models/provider_detection.dart';
import 'package:stream_hub/core/iptv/models/stream_protocol.dart';

/// A single classified entry extracted from a playlist.
@immutable
class PlaylistItem {
  final String title;
  final String? url;
  final String? group;
  final String? tvgId;
  final String? tvgName;
  final String? logo;
  final bool isRadio;
  final bool isMovie;
  final bool isSeries;
  final Map<String, String> catchup;
  final Map<String, String> attributes;
  final List<String> warnings;

  const PlaylistItem({
    required this.title,
    this.url,
    this.group,
    this.tvgId,
    this.tvgName,
    this.logo,
    this.isRadio = false,
    this.isMovie = false,
    this.isSeries = false,
    this.catchup = const {},
    this.attributes = const {},
    this.warnings = const [],
  });
}

/// Aggregate statistics for an analyzed playlist.
@immutable
class PlaylistStats {
  final int totalEntries;
  final int validEntries;
  final int invalidEntries;
  final int duplicateUrls;
  final String? encoding;
  final bool hasValidHeader;
  final Duration analysisDuration;

  const PlaylistStats({
    this.totalEntries = 0,
    this.validEntries = 0,
    this.invalidEntries = 0,
    this.duplicateUrls = 0,
    this.encoding,
    this.hasValidHeader = false,
    this.analysisDuration = Duration.zero,
  });
}

/// The complete output of the [PlaylistAnalyzer].
///
/// Extracts groups, channels, movies, series, radio, catch-up, timeshift,
/// headers, user agent, EPG references, TVG information, and custom attributes
/// from a playlist while collecting errors and warnings for diagnostics.
@immutable
class PlaylistAnalysis {
  final DetectedProviderKind providerKind;
  final List<PlaylistItem> items;
  final List<String> groups;

  final int channelCount;
  final int movieCount;
  final int seriesCount;
  final int radioCount;

  final bool hasCatchup;
  final bool hasTimeshift;

  final Map<String, String> headers;
  final String? userAgent;
  final String? referer;

  /// XMLTV/EPG sources referenced by the playlist (x-tvg-url, url-tvg, ...).
  final List<String> epgSources;

  /// TVG-level attributes from the `#EXTM3U` header.
  final Map<String, String> tvgInfo;

  /// Any custom/non-standard attributes encountered.
  final Map<String, String> customAttributes;

  final List<String> errors;
  final List<String> warnings;
  final PlaylistStats stats;

  /// Protocol distribution (e.g. `hls: 12`, `mpegTs: 3`).
  final Map<String, int> protocolDistribution;

  final DateTime analyzedAt;

  const PlaylistAnalysis({
    this.providerKind = DetectedProviderKind.unknown,
    this.items = const [],
    this.groups = const [],
    this.channelCount = 0,
    this.movieCount = 0,
    this.seriesCount = 0,
    this.radioCount = 0,
    this.hasCatchup = false,
    this.hasTimeshift = false,
    this.headers = const {},
    this.userAgent,
    this.referer,
    this.epgSources = const [],
    this.tvgInfo = const {},
    this.customAttributes = const {},
    this.errors = const [],
    this.warnings = const [],
    this.stats = const PlaylistStats(),
    this.protocolDistribution = const {},
    required this.analyzedAt,
  });

  bool get hasContent => items.isNotEmpty;

  String? protocolFor(String? url) {
    if (url == null || url.isEmpty) return null;
    return StreamProtocol.fromUrl(url).displayName;
  }
}
