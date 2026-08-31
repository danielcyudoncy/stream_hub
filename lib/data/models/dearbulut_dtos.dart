/// Data Transfer Objects for the dearbulut/iptv (IPTV Nexus) JSON API.
library;

class DearbulutMediaDto {
  final int? width;
  final int? height;
  final String? resolution;
  final double? frameRate;
  final int? bitrate;
  final String? videoCodec;
  final String? audioCodec;
  final int? variants;

  const DearbulutMediaDto({
    this.width,
    this.height,
    this.resolution,
    this.frameRate,
    this.bitrate,
    this.videoCodec,
    this.audioCodec,
    this.variants,
  });

  factory DearbulutMediaDto.fromJson(Map<String, dynamic> json) {
    return DearbulutMediaDto(
      width: (json['width'] is num) ? (json['width'] as num).toInt() : null,
      height: (json['height'] is num) ? (json['height'] as num).toInt() : null,
      resolution: json['resolution']?.toString(),
      frameRate: (json['frame_rate'] is num) ? (json['frame_rate'] as num).toDouble() : null,
      bitrate: (json['bitrate'] is num) ? (json['bitrate'] as num).toInt() : null,
      videoCodec: json['video_codec']?.toString(),
      audioCodec: json['audio_codec']?.toString(),
      variants: (json['variants'] is num) ? (json['variants'] as num).toInt() : null,
    );
  }
}

class DearbulutHealthDto {
  final String status;
  final double score;
  final double uptime;
  final String? checkedAt;
  final String? lastOnline;
  final int? latencyMs;
  final DearbulutMediaDto? media;

  const DearbulutHealthDto({
    this.status = 'unknown',
    this.score = 0.0,
    this.uptime = 0.0,
    this.checkedAt,
    this.lastOnline,
    this.latencyMs,
    this.media,
  });

  factory DearbulutHealthDto.fromJson(Map<String, dynamic> json) {
    return DearbulutHealthDto(
      status: (json['status'] ?? 'unknown').toString(),
      score: (json['score'] is num) ? (json['score'] as num).toDouble() : 0.0,
      uptime: (json['uptime'] is num) ? (json['uptime'] as num).toDouble() : 0.0,
      checkedAt: json['checked_at']?.toString(),
      lastOnline: json['last_online']?.toString(),
      latencyMs: (json['latency_ms'] is num) ? (json['latency_ms'] as num).toInt() : null,
      media: json['media'] is Map ? DearbulutMediaDto.fromJson(Map<String, dynamic>.from(json['media'])) : null,
    );
  }
}

class DearbulutStreamDto {
  final String? channel;
  final String? feed;
  final String? title;
  final String url;
  final String? referrer;
  final String? userAgent;
  final String? quality;
  final double? rank;
  final List<String> sources;
  final DearbulutHealthDto? health;

  const DearbulutStreamDto({
    this.channel,
    this.feed,
    this.title,
    required this.url,
    this.referrer,
    this.userAgent,
    this.quality,
    this.rank,
    this.sources = const [],
    this.health,
  });

  factory DearbulutStreamDto.fromJson(Map<String, dynamic> json) {
    final rawSources = json['sources'];
    final List<String> srcList = rawSources is List
        ? rawSources.map((e) => e.toString()).toList()
        : const [];

    return DearbulutStreamDto(
      channel: json['channel']?.toString(),
      feed: json['feed']?.toString(),
      title: json['title']?.toString(),
      url: (json['url'] ?? '').toString(),
      referrer: json['referrer']?.toString(),
      userAgent: json['user_agent']?.toString(),
      quality: json['quality']?.toString(),
      rank: (json['rank'] is num) ? (json['rank'] as num).toDouble() : null,
      sources: srcList,
      health: json['health'] is Map ? DearbulutHealthDto.fromJson(Map<String, dynamic>.from(json['health'])) : null,
    );
  }
}

class DearbulutChannelDto {
  final String id;
  final String name;
  final List<String> altNames;
  final String? network;
  final List<String> owners;
  final String? country;
  final String? subdivision;
  final List<String> categories;
  final List<String> languages;
  final List<String> broadcastArea;
  final List<String> timezones;
  final bool isNsfw;
  final String? launched;
  final String? closed;
  final String? replacedBy;
  final String? website;
  final String? logo;
  final double score;
  final bool online;
  final int streamCount;
  final String? bestQuality;
  final List<DearbulutStreamDto> streams;

  const DearbulutChannelDto({
    required this.id,
    required this.name,
    this.altNames = const [],
    this.network,
    this.owners = const [],
    this.country,
    this.subdivision,
    this.categories = const [],
    this.languages = const [],
    this.broadcastArea = const [],
    this.timezones = const [],
    this.isNsfw = false,
    this.launched,
    this.closed,
    this.replacedBy,
    this.website,
    this.logo,
    this.score = 0.0,
    this.online = false,
    this.streamCount = 0,
    this.bestQuality,
    this.streams = const [],
  });

  factory DearbulutChannelDto.fromJson(Map<String, dynamic> json) {
    final rawAlt = json['alt_names'];
    final List<String> altNames = rawAlt is List ? rawAlt.map((e) => e.toString()).toList() : const [];

    final rawOwners = json['owners'];
    final List<String> owners = rawOwners is List ? rawOwners.map((e) => e.toString()).toList() : const [];

    final rawCats = json['categories'];
    final List<String> categories = rawCats is List ? rawCats.map((e) => e.toString()).toList() : const [];

    final rawLangs = json['languages'];
    final List<String> languages = rawLangs is List ? rawLangs.map((e) => e.toString()).toList() : const [];

    final rawBroadcast = json['broadcast_area'];
    final List<String> broadcastArea = rawBroadcast is List ? rawBroadcast.map((e) => e.toString()).toList() : const [];

    final rawTz = json['timezones'];
    final List<String> timezones = rawTz is List ? rawTz.map((e) => e.toString()).toList() : const [];

    final rawStreams = json['streams'];
    final List<DearbulutStreamDto> streams = [];
    if (rawStreams is List) {
      for (final s in rawStreams) {
        if (s is Map) {
          streams.add(DearbulutStreamDto.fromJson(Map<String, dynamic>.from(s)));
        }
      }
    }

    return DearbulutChannelDto(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      altNames: altNames,
      network: json['network']?.toString(),
      owners: owners,
      country: json['country']?.toString(),
      subdivision: json['subdivision']?.toString(),
      categories: categories,
      languages: languages,
      broadcastArea: broadcastArea,
      timezones: timezones,
      isNsfw: json['is_nsfw'] == true || json['is_nsfw'] == 1,
      launched: json['launched']?.toString(),
      closed: json['closed']?.toString(),
      replacedBy: json['replaced_by']?.toString(),
      website: json['website']?.toString(),
      logo: json['logo']?.toString(),
      score: (json['score'] is num) ? (json['score'] as num).toDouble() : 0.0,
      online: json['online'] == true || json['online'] == 1,
      streamCount: (json['stream_count'] is num) ? (json['stream_count'] as num).toInt() : streams.length,
      bestQuality: json['best_quality']?.toString(),
      streams: streams,
    );
  }
}

class DearbulutCountryDto {
  final String name;
  final String code;
  final List<String> languages;
  final String? flag;
  final int channels;
  final int playable;
  final int online;

  const DearbulutCountryDto({
    required this.name,
    required this.code,
    this.languages = const [],
    this.flag,
    this.channels = 0,
    this.playable = 0,
    this.online = 0,
  });

  factory DearbulutCountryDto.fromJson(Map<String, dynamic> json) {
    final rawLangs = json['languages'];
    final List<String> languages = rawLangs is List ? rawLangs.map((e) => e.toString()).toList() : const [];

    return DearbulutCountryDto(
      name: (json['name'] ?? '').toString(),
      code: (json['code'] ?? '').toString().toUpperCase(),
      languages: languages,
      flag: json['flag']?.toString(),
      channels: (json['channels'] is num) ? (json['channels'] as num).toInt() : 0,
      playable: (json['playable'] is num) ? (json['playable'] as num).toInt() : 0,
      online: (json['online'] is num) ? (json['online'] as num).toInt() : 0,
    );
  }
}

class DearbulutCategoryDto {
  final String id;
  final String name;
  final String? description;
  final int channels;
  final int playable;
  final int online;

  const DearbulutCategoryDto({
    required this.id,
    required this.name,
    this.description,
    this.channels = 0,
    this.playable = 0,
    this.online = 0,
  });

  factory DearbulutCategoryDto.fromJson(Map<String, dynamic> json) {
    return DearbulutCategoryDto(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: json['description']?.toString(),
      channels: (json['channels'] is num) ? (json['channels'] as num).toInt() : 0,
      playable: (json['playable'] is num) ? (json['playable'] as num).toInt() : 0,
      online: (json['online'] is num) ? (json['online'] as num).toInt() : 0,
    );
  }
}
