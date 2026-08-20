/// Represents an intro or outro segment in a media episode/stream.
class IntroSegment {
  final Duration start;
  final Duration end;
  final String source;
  final double confidence;
  final String? episodeId;

  const IntroSegment({
    required this.start,
    required this.end,
    this.source = 'metadata',
    this.confidence = 1.0,
    this.episodeId,
  });

  Duration get duration => end - start;

  bool containsPosition(Duration position) {
    return position >= start && position < end;
  }

  Map<String, dynamic> toMap() {
    return {
      'start': start.inMilliseconds,
      'end': end.inMilliseconds,
      'source': source,
      'confidence': confidence,
      if (episodeId != null) 'episodeId': episodeId,
    };
  }

  factory IntroSegment.fromMap(Map<dynamic, dynamic> map) {
    return IntroSegment(
      start: Duration(milliseconds: int.tryParse(map['start']?.toString() ?? '0') ?? 0),
      end: Duration(milliseconds: int.tryParse(map['end']?.toString() ?? '0') ?? 0),
      source: map['source']?.toString() ?? 'metadata',
      confidence: double.tryParse(map['confidence']?.toString() ?? '1.0') ?? 1.0,
      episodeId: map['episodeId']?.toString(),
    );
  }

  IntroSegment copyWith({
    Duration? start,
    Duration? end,
    String? source,
    double? confidence,
    String? episodeId,
  }) {
    return IntroSegment(
      start: start ?? this.start,
      end: end ?? this.end,
      source: source ?? this.source,
      confidence: confidence ?? this.confidence,
      episodeId: episodeId ?? this.episodeId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IntroSegment &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end &&
          episodeId == other.episodeId;

  @override
  int get hashCode => start.hashCode ^ end.hashCode ^ episodeId.hashCode;
}
