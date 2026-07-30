import 'package:stream_hub/core/media/enums/player_quality.dart';

abstract class PlaybackEvent {
  final String sessionId;
  final DateTime occurredAt;

  const PlaybackEvent({
    required this.sessionId,
    required this.occurredAt,
  });
}

class PlaybackStartedEvent implements PlaybackEvent {
  @override
  final String sessionId;
  final String itemId;
  @override
  final DateTime occurredAt;

  const PlaybackStartedEvent({
    required this.sessionId,
    required this.itemId,
    required this.occurredAt,
  });
}

class PlaybackPausedEvent implements PlaybackEvent {
  @override
  final String sessionId;
  final Duration position;
  @override
  final DateTime occurredAt;

  const PlaybackPausedEvent({
    required this.sessionId,
    required this.position,
    required this.occurredAt,
  });
}

class PlaybackResumedEvent implements PlaybackEvent {
  @override
  final String sessionId;
  @override
  final DateTime occurredAt;

  const PlaybackResumedEvent({
    required this.sessionId,
    required this.occurredAt,
  });
}

class PlaybackBufferingEvent implements PlaybackEvent {
  @override
  final String sessionId;
  final Duration position;
  @override
  final DateTime occurredAt;

  const PlaybackBufferingEvent({
    required this.sessionId,
    required this.position,
    required this.occurredAt,
  });
}

class PlaybackSeekingEvent implements PlaybackEvent {
  @override
  final String sessionId;
  final Duration position;
  @override
  final DateTime occurredAt;

  const PlaybackSeekingEvent({
    required this.sessionId,
    required this.position,
    required this.occurredAt,
  });
}

class PlaybackCompletedEvent implements PlaybackEvent {
  @override
  final String sessionId;
  final String itemId;
  @override
  final DateTime occurredAt;

  const PlaybackCompletedEvent({
    required this.sessionId,
    required this.itemId,
    required this.occurredAt,
  });
}

class PlaybackErrorEvent implements PlaybackEvent {
  @override
  final String sessionId;
  final String error;
  final String? stackTrace;
  @override
  final DateTime occurredAt;

  const PlaybackErrorEvent({
    required this.sessionId,
    required this.error,
    this.stackTrace,
    required this.occurredAt,
  });
}

class SubtitleChangedEvent implements PlaybackEvent {
  @override
  final String sessionId;
  final String subtitleTrackId;
  @override
  final DateTime occurredAt;

  const SubtitleChangedEvent({
    required this.sessionId,
    required this.subtitleTrackId,
    required this.occurredAt,
  });
}

class AudioChangedEvent implements PlaybackEvent {
  @override
  final String sessionId;
  final String audioTrackId;
  @override
  final DateTime occurredAt;

  const AudioChangedEvent({
    required this.sessionId,
    required this.audioTrackId,
    required this.occurredAt,
  });
}

class QualityChangedEvent implements PlaybackEvent {
  @override
  final String sessionId;
  final PlayerQuality quality;
  @override
  final DateTime occurredAt;

  const QualityChangedEvent({
    required this.sessionId,
    required this.quality,
    required this.occurredAt,
  });
}
