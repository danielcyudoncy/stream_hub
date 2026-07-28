enum MediaType {
  channel,
  movie,
  series,
  episode,
  program,
  collection,
  recording,
  liveEvent;

  String get displayName {
    switch (this) {
      case MediaType.channel:
        return 'Channel';
      case MediaType.movie:
        return 'Movie';
      case MediaType.series:
        return 'Series';
      case MediaType.episode:
        return 'Episode';
      case MediaType.program:
        return 'Program';
      case MediaType.collection:
        return 'Collection';
      case MediaType.recording:
        return 'Recording';
      case MediaType.liveEvent:
        return 'Live Event';
    }
  }
}
