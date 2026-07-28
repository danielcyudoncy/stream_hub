class MediaMetadata {
  final String? resolution;
  final String? codec;
  final String? audio;
  final List<String>? subtitles;
  final int? runtime;
  final DateTime? releaseDate;
  final String? director;
  final List<String>? cast;
  final String? studio;
  final String? container;
  final int? bitrate;

  const MediaMetadata({
    this.resolution,
    this.codec,
    this.audio,
    this.subtitles,
    this.runtime,
    this.releaseDate,
    this.director,
    this.cast,
    this.studio,
    this.container,
    this.bitrate,
  });

  MediaMetadata copyWith({
    String? resolution,
    String? codec,
    String? audio,
    List<String>? subtitles,
    int? runtime,
    DateTime? releaseDate,
    String? director,
    List<String>? cast,
    String? studio,
    String? container,
    int? bitrate,
  }) {
    return MediaMetadata(
      resolution: resolution ?? this.resolution,
      codec: codec ?? this.codec,
      audio: audio ?? this.audio,
      subtitles: subtitles ?? this.subtitles,
      runtime: runtime ?? this.runtime,
      releaseDate: releaseDate ?? this.releaseDate,
      director: director ?? this.director,
      cast: cast ?? this.cast,
      studio: studio ?? this.studio,
      container: container ?? this.container,
      bitrate: bitrate ?? this.bitrate,
    );
  }
}
