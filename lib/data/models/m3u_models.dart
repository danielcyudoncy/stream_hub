import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/data/models/media_item.dart';

class M3UChannel {
  final String id;
  final String title;
  final String? streamUrl;
  final String? logo;
  final String? group;
  final String? tvgId;
  final String? tvgName;
  final bool isRadio;
  final String? language;
  final String? country;
  final Map<String, String> catchup;
  final Map<String, String> attributes;
  final List<String> warnings;

  const M3UChannel({
    required this.id,
    required this.title,
    this.streamUrl,
    this.logo,
    this.group,
    this.tvgId,
    this.tvgName,
    this.isRadio = false,
    this.language,
    this.country,
    this.catchup = const {},
    this.attributes = const {},
    this.warnings = const [],
  });

  M3UChannel copyWith({
    String? id,
    String? title,
    String? streamUrl,
    String? logo,
    String? group,
    String? tvgId,
    String? tvgName,
    bool? isRadio,
    String? language,
    String? country,
    Map<String, String>? catchup,
    Map<String, String>? attributes,
    List<String>? warnings,
  }) {
    return M3UChannel(
      id: id ?? this.id,
      title: title ?? this.title,
      streamUrl: streamUrl ?? this.streamUrl,
      logo: logo ?? this.logo,
      group: group ?? this.group,
      tvgId: tvgId ?? this.tvgId,
      tvgName: tvgName ?? this.tvgName,
      isRadio: isRadio ?? this.isRadio,
      language: language ?? this.language,
      country: country ?? this.country,
      catchup: catchup ?? this.catchup,
      attributes: attributes ?? this.attributes,
      warnings: warnings ?? this.warnings,
    );
  }
}

class M3UPlaylistResult {
  final List<M3UChannel> channels;
  final List<String> groups;
  final List<String> languages;
  final List<String> countries;
  final int totalEntries;
  final int validEntries;
  final int invalidEntries;
  final int duplicateEntries;
  final List<String> warnings;
  final String? encoding;
  final bool hasValidHeader;

  const M3UPlaylistResult({
    this.channels = const [],
    this.groups = const [],
    this.languages = const [],
    this.countries = const [],
    this.totalEntries = 0,
    this.validEntries = 0,
    this.invalidEntries = 0,
    this.duplicateEntries = 0,
    this.warnings = const [],
    this.encoding,
    this.hasValidHeader = false,
  });
}

class M3UValidationResult {
  final bool isValid;
  final bool hasValidHeader;
  final String? encoding;
  final List<String> errors;
  final List<String> warnings;
  final int duplicateCount;
  final int missingUrlCount;
  final int malformedEntryCount;

  const M3UValidationResult({
    this.isValid = true,
    this.hasValidHeader = false,
    this.encoding,
    this.errors = const [],
    this.warnings = const [],
    this.duplicateCount = 0,
    this.missingUrlCount = 0,
    this.malformedEntryCount = 0,
  });
}

class M3UStatistics {
  final int totalItems;
  final int channels;
  final int radioCount;
  final int categories;
  final int languages;
  final int countries;
  final int invalidEntries;
  final int duplicates;
  final Duration syncDuration;
  final DateTime lastSync;

  const M3UStatistics({
    this.totalItems = 0,
    this.channels = 0,
    this.radioCount = 0,
    this.categories = 0,
    this.languages = 0,
    this.countries = 0,
    this.invalidEntries = 0,
    this.duplicates = 0,
    this.syncDuration = Duration.zero,
    required this.lastSync,
  });
}

class M3UConfig {
  final String sourceUrl;
  final String? localPath;
  final String? username;
  final String? password;
  final Map<String, String> headers;
  final Duration timeout;
  final int maxRetries;
  final Duration retryDelay;
  final bool followRedirects;
  final int maxRedirects;

  const M3UConfig({
    this.sourceUrl = '',
    this.localPath,
    this.username,
    this.password,
    this.headers = const {},
    this.timeout = const Duration(seconds: 30),
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 2),
    this.followRedirects = true,
    this.maxRedirects = 5,
  });

  M3UConfig copyWith({
    String? sourceUrl,
    String? localPath,
    String? username,
    String? password,
    Map<String, String>? headers,
    Duration? timeout,
    int? maxRetries,
    Duration? retryDelay,
    bool? followRedirects,
    int? maxRedirects,
  }) {
    return M3UConfig(
      sourceUrl: sourceUrl ?? this.sourceUrl,
      localPath: localPath ?? this.localPath,
      username: username ?? this.username,
      password: password ?? this.password,
      headers: headers ?? this.headers,
      timeout: timeout ?? this.timeout,
      maxRetries: maxRetries ?? this.maxRetries,
      retryDelay: retryDelay ?? this.retryDelay,
      followRedirects: followRedirects ?? this.followRedirects,
      maxRedirects: maxRedirects ?? this.maxRedirects,
    );
  }
}

class M3UPlaylistCache {
  final String sourceId;
  final String rawPlaylist;
  final List<M3UChannel> channels;
  final M3UStatistics statistics;
  final M3UValidationResult validation;
  final DateTime cachedAt;
  final DateTime expiresAt;
  final String? etag;
  final String? lastModified;
  final String contentHash;

  const M3UPlaylistCache({
    required this.sourceId,
    required this.rawPlaylist,
    required this.channels,
    required this.statistics,
    required this.validation,
    required this.cachedAt,
    required this.expiresAt,
    this.etag,
    this.lastModified,
    required this.contentHash,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

extension M3UChannelToMediaItem on M3UChannel {
  MediaItem toMediaItem(String providerId, {MediaType? mediaType}) {
    final genres = <String>[];
    if (group != null && group!.isNotEmpty) genres.add(group!);
    if (language != null && language!.isNotEmpty) genres.add(language!);
    if (country != null && country!.isNotEmpty) genres.add(country!);

    return MediaItem(
      id: id,
      providerId: providerId,
      providerType: MediaSourceType.m3u,
      mediaType: mediaType ?? MediaType.channel,
      title: title,
      subtitle: tvgName,
      description: tvgId,
      poster: logo,
      thumbnail: logo,
      genres: genres.toSet().toList(),
      language: language,
      country: country,
      metadata: {
        'tvgId': tvgId ?? '',
        'tvgName': tvgName ?? '',
        'groupTitle': group ?? '',
        'isRadio': isRadio,
        'streamUrl': streamUrl ?? '',
        'catchup': catchup,
        'attributes': attributes,
        if (warnings.isNotEmpty) 'warnings': warnings,
      },
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}
