import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/data/models/media_item.dart';

class XMLTVChannel {
  final String id;
  final String displayName;
  final String? iconUrl;
  final String? language;
  final String? country;
  final List<String> aliases;
  final Map<String, dynamic> metadata;

  const XMLTVChannel({
    required this.id,
    required this.displayName,
    this.iconUrl,
    this.language,
    this.country,
    this.aliases = const [],
    this.metadata = const {},
  });

  XMLTVChannel copyWith({
    String? id,
    String? displayName,
    String? iconUrl,
    String? language,
    String? country,
    List<String>? aliases,
    Map<String, dynamic>? metadata,
  }) {
    return XMLTVChannel(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      iconUrl: iconUrl ?? this.iconUrl,
      language: language ?? this.language,
      country: country ?? this.country,
      aliases: aliases ?? this.aliases,
      metadata: metadata ?? this.metadata,
    );
  }

  MediaItem toMediaItem(String providerId) {
    final genres = <String>[];
    if (country != null && country!.isNotEmpty) genres.add(country!);
    if (language != null && language!.isNotEmpty) genres.add(language!);

    return MediaItem(
      id: 'xmltv-channel-$providerId-${id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}',
      providerId: providerId,
      providerType: MediaSourceType.xmltv,
      mediaType: MediaType.channel,
      title: displayName,
      poster: iconUrl,
      thumbnail: iconUrl,
      genres: genres.toSet().toList(),
      language: language,
      country: country,
      metadata: {
        'tvgId': id,
        'displayName': displayName,
        'iconUrl': iconUrl ?? '',
        'aliases': aliases,
        ...metadata,
      },
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

class XMLTVProgram {
  final String id;
  final String channelId;
  final String title;
  final String? subtitle;
  final String? description;
  final List<String> categories;
  final String? language;
  final String? country;
  final DateTime start;
  final DateTime end;
  final Duration duration;
  final String? episodeNum;
  final String? season;
  final String? episodeTitle;
  final double? rating;
  final List<String> cast;
  final List<String> directors;
  final List<String> writers;
  final List<String> producers;
  final List<String> presenters;
  final List<String> guests;
  final String? poster;
  final bool isLive;
  final bool isNew;
  final bool isPremiere;
  final bool isPreviouslyShown;
  final String? videoAspect;
  final String? videoQuality;
  final String? videoCodec;
  final String? audioStereo;
  final String? audioCodec;
  final int? audioChannels;
  final List<String> subtitleLanguages;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  const XMLTVProgram({
    required this.id,
    required this.channelId,
    required this.title,
    this.subtitle,
    this.description,
    this.categories = const [],
    this.language,
    this.country,
    required this.start,
    required this.end,
    required this.duration,
    this.episodeNum,
    this.season,
    this.episodeTitle,
    this.rating,
    this.cast = const [],
    this.directors = const [],
    this.writers = const [],
    this.producers = const [],
    this.presenters = const [],
    this.guests = const [],
    this.poster,
    this.isLive = false,
    this.isNew = false,
    this.isPremiere = false,
    this.isPreviouslyShown = false,
    this.videoAspect,
    this.videoQuality,
    this.videoCodec,
    this.audioStereo,
    this.audioCodec,
    this.audioChannels,
    this.subtitleLanguages = const [],
    this.metadata = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  XMLTVProgram copyWith({
    String? id,
    String? channelId,
    String? title,
    String? subtitle,
    String? description,
    List<String>? categories,
    String? language,
    String? country,
    DateTime? start,
    DateTime? end,
    Duration? duration,
    String? episodeNum,
    String? season,
    String? episodeTitle,
    double? rating,
    List<String>? cast,
    List<String>? directors,
    List<String>? writers,
    List<String>? producers,
    List<String>? presenters,
    List<String>? guests,
    String? poster,
    bool? isLive,
    bool? isNew,
    bool? isPremiere,
    bool? isPreviouslyShown,
    String? videoAspect,
    String? videoQuality,
    String? videoCodec,
    String? audioStereo,
    String? audioCodec,
    int? audioChannels,
    List<String>? subtitleLanguages,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return XMLTVProgram(
      id: id ?? this.id,
      channelId: channelId ?? this.channelId,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      description: description ?? this.description,
      categories: categories ?? this.categories,
      language: language ?? this.language,
      country: country ?? this.country,
      start: start ?? this.start,
      end: end ?? this.end,
      duration: duration ?? this.duration,
      episodeNum: episodeNum ?? this.episodeNum,
      season: season ?? this.season,
      episodeTitle: episodeTitle ?? this.episodeTitle,
      rating: rating ?? this.rating,
      cast: cast ?? this.cast,
      directors: directors ?? this.directors,
      writers: writers ?? this.writers,
      producers: producers ?? this.producers,
      presenters: presenters ?? this.presenters,
      guests: guests ?? this.guests,
      poster: poster ?? this.poster,
      isLive: isLive ?? this.isLive,
      isNew: isNew ?? this.isNew,
      isPremiere: isPremiere ?? this.isPremiere,
      isPreviouslyShown: isPreviouslyShown ?? this.isPreviouslyShown,
      videoAspect: videoAspect ?? this.videoAspect,
      videoQuality: videoQuality ?? this.videoQuality,
      videoCodec: videoCodec ?? this.videoCodec,
      audioStereo: audioStereo ?? this.audioStereo,
      audioCodec: audioCodec ?? this.audioCodec,
      audioChannels: audioChannels ?? this.audioChannels,
      subtitleLanguages: subtitleLanguages ?? this.subtitleLanguages,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  MediaItem toMediaItem(String providerId) {
    final genres = <String>[];
    genres.addAll(categories);
    if (language != null && language!.isNotEmpty) genres.add(language!);
    if (country != null && country!.isNotEmpty) genres.add(country!);

    return MediaItem(
      id: id,
      providerId: providerId,
      providerType: MediaSourceType.xmltv,
      mediaType: MediaType.program,
      title: title,
      subtitle: subtitle,
      description: description,
      poster: poster,
      genres: genres.toSet().toList(),
      language: language,
      country: country,
      rating: rating,
      metadata: {
        'channelId': channelId,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'duration': duration.inMinutes,
        'episodeNum': episodeNum ?? '',
        'season': season ?? '',
        'episodeTitle': episodeTitle ?? '',
        'isLive': isLive,
        'isNew': isNew,
        'isPremiere': isPremiere,
        'isPreviouslyShown': isPreviouslyShown,
        'videoAspect': videoAspect ?? '',
        'videoQuality': videoQuality ?? '',
        'videoCodec': videoCodec ?? '',
        'audioStereo': audioStereo ?? '',
        'audioCodec': audioCodec ?? '',
        'audioChannels': audioChannels ?? 0,
        'subtitleLanguages': subtitleLanguages,
        'cast': cast,
        'directors': directors,
        'writers': writers,
        'producers': producers,
        'presenters': presenters,
        'guests': guests,
        ...metadata,
      },
      createdAt: start,
      updatedAt: end,
    );
  }
}

class XMLTVGuide {
  final String sourceId;
  final List<XMLTVChannel> channels;
  final List<XMLTVProgram> programs;
  final DateTime generatedAt;
  final String? version;
  final int? sizeBytes;
  final String? encoding;

  const XMLTVGuide({
    required this.sourceId,
    this.channels = const [],
    this.programs = const [],
    required this.generatedAt,
    this.version,
    this.sizeBytes,
    this.encoding,
  });

  XMLTVGuide copyWith({
    String? sourceId,
    List<XMLTVChannel>? channels,
    List<XMLTVProgram>? programs,
    DateTime? generatedAt,
    String? version,
    int? sizeBytes,
    String? encoding,
  }) {
    return XMLTVGuide(
      sourceId: sourceId ?? this.sourceId,
      channels: channels ?? this.channels,
      programs: programs ?? this.programs,
      generatedAt: generatedAt ?? this.generatedAt,
      version: version ?? this.version,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      encoding: encoding ?? this.encoding,
    );
  }

  int get programCount => programs.length;
  int get channelCount => channels.length;
  Set<String> get categories => programs.expand((p) => p.categories).toSet();
  Set<String> get languages => programs.where((p) => p.language != null).map((p) => p.language!).toSet();
  Set<String> get countries => programs.where((p) => p.country != null).map((p) => p.country!).toSet();
  Set<String> get ratings => programs.where((p) => p.rating != null).map((p) => p.rating!.toString()).toSet();
}

class XMLTVConfig {
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
  final bool compressGz;
  final String? guideVersion;

  const XMLTVConfig({
    this.sourceUrl = '',
    this.localPath,
    this.username,
    this.password,
    this.headers = const {},
    this.timeout = const Duration(seconds: 60),
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 2),
    this.followRedirects = true,
    this.maxRedirects = 5,
    this.compressGz = true,
    this.guideVersion,
  });

  XMLTVConfig copyWith({
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
    bool? compressGz,
    String? guideVersion,
  }) {
    return XMLTVConfig(
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
      compressGz: compressGz ?? this.compressGz,
      guideVersion: guideVersion ?? this.guideVersion,
    );
  }
}

class XMLTVGuideCache {
  final String sourceId;
  final XMLTVGuide guide;
  final String contentHash;
  final DateTime cachedAt;
  final DateTime expiresAt;
  final int? sizeBytes;
  final String? encoding;
  final String? version;

  const XMLTVGuideCache({
    required this.sourceId,
    required this.guide,
    required this.contentHash,
    required this.cachedAt,
    required this.expiresAt,
    this.sizeBytes,
    this.encoding,
    this.version,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class XMLTVStatistics {
  final int totalPrograms;
  final int totalChannels;
  final int matchedChannels;
  final int unmatchedChannels;
  final int missingChannels;
  final int duplicatePrograms;
  final int categories;
  final int languages;
  final int ratings;
  final Duration syncDuration;
  final DateTime lastSync;
  final int guideSizeBytes;
  final String? guideVersion;

  const XMLTVStatistics({
    this.totalPrograms = 0,
    this.totalChannels = 0,
    this.matchedChannels = 0,
    this.unmatchedChannels = 0,
    this.missingChannels = 0,
    this.duplicatePrograms = 0,
    this.categories = 0,
    this.languages = 0,
    this.ratings = 0,
    this.syncDuration = Duration.zero,
    required this.lastSync,
    this.guideSizeBytes = 0,
    this.guideVersion,
  });
}

class XMLTVHealth {
  final bool isConnected;
  final int latencyMs;
  final bool isAuthenticated;
  final DateTime? lastSync;
  final int guideSizeBytes;
  final int programCount;
  final int channelCount;
  final int matchedChannels;
  final int unmatchedChannels;
  final String? guideVersion;
  final List<String> errors;

  const XMLTVHealth({
    this.isConnected = false,
    this.latencyMs = 0,
    this.isAuthenticated = false,
    this.lastSync,
    this.guideSizeBytes = 0,
    this.programCount = 0,
    this.channelCount = 0,
    this.matchedChannels = 0,
    this.unmatchedChannels = 0,
    this.guideVersion,
    this.errors = const [],
  });

  XMLTVHealth copyWith({
    bool? isConnected,
    int? latencyMs,
    bool? isAuthenticated,
    DateTime? lastSync,
    int? guideSizeBytes,
    int? programCount,
    int? channelCount,
    int? matchedChannels,
    int? unmatchedChannels,
    String? guideVersion,
    List<String>? errors,
  }) {
    return XMLTVHealth(
      isConnected: isConnected ?? this.isConnected,
      latencyMs: latencyMs ?? this.latencyMs,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      lastSync: lastSync ?? this.lastSync,
      guideSizeBytes: guideSizeBytes ?? this.guideSizeBytes,
      programCount: programCount ?? this.programCount,
      channelCount: channelCount ?? this.channelCount,
      matchedChannels: matchedChannels ?? this.matchedChannels,
      unmatchedChannels: unmatchedChannels ?? this.unmatchedChannels,
      guideVersion: guideVersion ?? this.guideVersion,
      errors: errors ?? this.errors,
    );
  }
}