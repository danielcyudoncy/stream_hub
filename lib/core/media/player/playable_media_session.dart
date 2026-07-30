import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/playable_stream.dart';

class PlayableMediaSession {
  final String id;
  final MediaItem mediaItem;
  final PlayableStream stream;
  final String providerId;
  final Duration resumePosition;
  final double completionPercentage;
  final List<dynamic> availableAudioTracks;
  final List<dynamic> availableSubtitleTracks;
  final PlaybackCapabilities capabilities;
  final SessionMetadata metadata;

  const PlayableMediaSession({
    required this.id,
    required this.mediaItem,
    required this.stream,
    required this.providerId,
    this.resumePosition = Duration.zero,
    this.completionPercentage = 0.0,
    this.availableAudioTracks = const [],
    this.availableSubtitleTracks = const [],
    required this.capabilities,
    required this.metadata,
  });

  PlayableMediaSession copyWith({
    String? id,
    MediaItem? mediaItem,
    PlayableStream? stream,
    String? providerId,
    Duration? resumePosition,
    double? completionPercentage,
    List<dynamic>? availableAudioTracks,
    List<dynamic>? availableSubtitleTracks,
    PlaybackCapabilities? capabilities,
    SessionMetadata? metadata,
  }) {
    return PlayableMediaSession(
      id: id ?? this.id,
      mediaItem: mediaItem ?? this.mediaItem,
      stream: stream ?? this.stream,
      providerId: providerId ?? this.providerId,
      resumePosition: resumePosition ?? this.resumePosition,
      completionPercentage: completionPercentage ?? this.completionPercentage,
      availableAudioTracks: availableAudioTracks ?? this.availableAudioTracks,
      availableSubtitleTracks:
          availableSubtitleTracks ?? this.availableSubtitleTracks,
      capabilities: capabilities ?? this.capabilities,
      metadata: metadata ?? this.metadata,
    );
  }
}

class PlaybackCapabilities {
  final bool canResume;
  final bool canPause;
  final bool canSeek;
  final bool canChangeQuality;
  final bool canChangeAudioTrack;
  final bool canChangeSubtitle;
  final bool canChangeSpeed;
  final bool canChangeAspectRatio;
  final bool canPictureInPicture;
  final bool canCast;
  final bool supportsAudioOnly;
  final bool supportsSubtitles;
  final bool supportsMultipleQualities;

  const PlaybackCapabilities({
    this.canResume = true,
    this.canPause = true,
    this.canSeek = true,
    this.canChangeQuality = false,
    this.canChangeAudioTrack = false,
    this.canChangeSubtitle = false,
    this.canChangeSpeed = true,
    this.canChangeAspectRatio = true,
    this.canPictureInPicture = false,
    this.canCast = false,
    this.supportsAudioOnly = false,
    this.supportsSubtitles = false,
    this.supportsMultipleQualities = false,
  });

  PlaybackCapabilities copyWith({
    bool? canResume,
    bool? canPause,
    bool? canSeek,
    bool? canChangeQuality,
    bool? canChangeAudioTrack,
    bool? canChangeSubtitle,
    bool? canChangeSpeed,
    bool? canChangeAspectRatio,
    bool? canPictureInPicture,
    bool? canCast,
    bool? supportsAudioOnly,
    bool? supportsSubtitles,
    bool? supportsMultipleQualities,
  }) {
    return PlaybackCapabilities(
      canResume: canResume ?? this.canResume,
      canPause: canPause ?? this.canPause,
      canSeek: canSeek ?? this.canSeek,
      canChangeQuality: canChangeQuality ?? this.canChangeQuality,
      canChangeAudioTrack: canChangeAudioTrack ?? this.canChangeAudioTrack,
      canChangeSubtitle: canChangeSubtitle ?? this.canChangeSubtitle,
      canChangeSpeed: canChangeSpeed ?? this.canChangeSpeed,
      canChangeAspectRatio: canChangeAspectRatio ?? this.canChangeAspectRatio,
      canPictureInPicture: canPictureInPicture ?? this.canPictureInPicture,
      canCast: canCast ?? this.canCast,
      supportsAudioOnly: supportsAudioOnly ?? this.supportsAudioOnly,
      supportsSubtitles: supportsSubtitles ?? this.supportsSubtitles,
      supportsMultipleQualities:
          supportsMultipleQualities ?? this.supportsMultipleQualities,
    );
  }
}

class SessionMetadata {
  final String? title;
  final String? description;
  final String? posterUrl;
  final String? channelNumber;
  final String? providerType;
  final bool isLive;
  final Duration? duration;
  final Map<String, dynamic> extra;

  const SessionMetadata({
    this.title,
    this.description,
    this.posterUrl,
    this.channelNumber,
    this.providerType,
    this.isLive = false,
    this.duration,
    this.extra = const {},
  });
}
