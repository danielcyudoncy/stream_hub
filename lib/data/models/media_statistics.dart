class MediaStatistics {
  final int totalItems;
  final int channels;
  final int movies;
  final int series;
  final int episodes;
  final int programs;
  final int categories;
  final Duration syncDuration;
  final DateTime lastSync;

  const MediaStatistics({
    this.totalItems = 0,
    this.channels = 0,
    this.movies = 0,
    this.series = 0,
    this.episodes = 0,
    this.programs = 0,
    this.categories = 0,
    this.syncDuration = Duration.zero,
    required this.lastSync,
  });
}
