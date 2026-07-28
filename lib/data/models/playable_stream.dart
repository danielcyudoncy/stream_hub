class PlayableStream {
  final String url;
  final Map<String, String>? headers;
  final Map<String, String>? cookies;
  final List<SubtitleTrack>? subtitleTracks;
  final List<AudioTrack>? audioTracks;
  final String? quality;
  final String? license;
  final Map<String, dynamic>? drm;
  final DateTime? expires;

  const PlayableStream({
    required this.url,
    this.headers,
    this.cookies,
    this.subtitleTracks,
    this.audioTracks,
    this.quality,
    this.license,
    this.drm,
    this.expires,
  });

  bool get isExpired => expires != null && DateTime.now().isAfter(expires!);
}

class SubtitleTrack {
  final String id;
  final String label;
  final String language;
  final String url;
  final bool isForced;

  const SubtitleTrack({
    required this.id,
    required this.label,
    required this.language,
    required this.url,
    this.isForced = false,
  });
}

class AudioTrack {
  final String id;
  final String label;
  final String language;
  final String? codec;

  const AudioTrack({
    required this.id,
    required this.label,
    required this.language,
    this.codec,
  });
}
