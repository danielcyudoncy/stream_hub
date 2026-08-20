import 'package:stream_hub/data/models/media_item.dart';

/// Represents a season group with a season number, display name, and list of episodes.
class SeasonGroup {
  final int number;
  final String name;
  final List<MediaItem> episodes;

  const SeasonGroup({
    required this.number,
    required this.name,
    required this.episodes,
  });

  SeasonGroup copyWith({
    int? number,
    String? name,
    List<MediaItem>? episodes,
  }) {
    return SeasonGroup(
      number: number ?? this.number,
      name: name ?? this.name,
      episodes: episodes ?? this.episodes,
    );
  }
}

/// Result returned when resolving the next episode.
class NextEpisodeResult {
  final MediaItem? nextEpisode;
  final bool isSeriesCompleted;
  final SeasonGroup? nextSeason;

  const NextEpisodeResult({
    this.nextEpisode,
    this.isSeriesCompleted = false,
    this.nextSeason,
  });
}

/// Deterministic resolver for determining the next and previous episodes in a series.
///
/// Implements deterministic season and episode sorting, graceful handling of missing
/// episodes, season boundaries (e.g. S01E10 -> S02E01 when S01E11 doesn't exist),
/// non-contiguous seasons, and overall series completion detection.
class NextEpisodeResolver {
  const NextEpisodeResolver();

  /// Extracts the season number from a [MediaItem].
  static int seasonNumberFor(MediaItem item) {
    final direct = item.metadata['seasonNumber'] ??
        item.metadata['seasonId'] ??
        item.metadata['season_num'] ??
        item.metadata['season'];
    if (direct != null) {
      final parsed = int.tryParse(direct.toString());
      if (parsed != null) return parsed;
    }
    final match = RegExp(r'S(\d+)', caseSensitive: false).firstMatch(item.subtitle ?? '') ??
        RegExp(r'S(\d+)', caseSensitive: false).firstMatch(item.title);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 0;
    }
    return 0;
  }

  /// Extracts the episode number from a [MediaItem].
  static int episodeNumberFor(MediaItem item) {
    final direct = item.metadata['episodeNumber'] ??
        item.metadata['episode_num'] ??
        item.metadata['episodeId'] ??
        item.metadata['streamId'] ??
        item.metadata['stream_id'];
    if (direct != null) {
      final parsed = int.tryParse(direct.toString());
      if (parsed != null) return parsed;
    }
    final match = RegExp(r'E(\d+)', caseSensitive: false).firstMatch(item.subtitle ?? '') ??
        RegExp(r'E(\d+)', caseSensitive: false).firstMatch(item.title);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 0;
    }
    return 0;
  }

  /// Sorts a list of season groups in ascending numerical order,
  /// and within each season sorts episodes in ascending numerical order.
  List<SeasonGroup> normalizeAndSortSeasons(List<SeasonGroup> seasons) {
    final sortedSeasons = seasons.map((season) {
      final sortedEpisodes = List<MediaItem>.from(season.episodes)..sort((a, b) {
        final epA = episodeNumberFor(a);
        final epB = episodeNumberFor(b);
        if (epA != epB) return epA.compareTo(epB);
        return a.title.compareTo(b.title);
      });
      return season.copyWith(episodes: sortedEpisodes);
    }).toList();

    sortedSeasons.sort((a, b) => a.number.compareTo(b.number));
    return sortedSeasons;
  }

  /// Resolves the next episode after [currentEpisode] given the available [seasons].
  NextEpisodeResult resolveNext({
    required MediaItem currentEpisode,
    required List<SeasonGroup> seasons,
  }) {
    if (seasons.isEmpty) {
      return const NextEpisodeResult(isSeriesCompleted: true);
    }

    final sortedSeasons = normalizeAndSortSeasons(seasons);
    final currentSeasonNum = seasonNumberFor(currentEpisode);
    final currentEpisodeNum = episodeNumberFor(currentEpisode);

    // 1. Locate the current season group
    var currentSeasonIndex = sortedSeasons.indexWhere((s) => s.number == currentSeasonNum);
    if (currentSeasonIndex == -1) {
      // If season number wasn't matched directly, find by episode ID in episodes list
      currentSeasonIndex = sortedSeasons.indexWhere(
        (s) => s.episodes.any((e) => e.id == currentEpisode.id),
      );
    }

    if (currentSeasonIndex != -1) {
      final currentSeason = sortedSeasons[currentSeasonIndex];
      final currentEpIndex = currentSeason.episodes.indexWhere(
        (e) => e.id == currentEpisode.id || episodeNumberFor(e) == currentEpisodeNum,
      );

      // Check if there is another episode in the current season
      if (currentEpIndex != -1 && currentEpIndex + 1 < currentSeason.episodes.length) {
        return NextEpisodeResult(
          nextEpisode: currentSeason.episodes[currentEpIndex + 1],
          isSeriesCompleted: false,
          nextSeason: currentSeason,
        );
      }

      // If at the end of the current season, look for the next available season with episodes
      for (var sIdx = currentSeasonIndex + 1; sIdx < sortedSeasons.length; sIdx++) {
        final nextSeason = sortedSeasons[sIdx];
        if (nextSeason.episodes.isNotEmpty) {
          return NextEpisodeResult(
            nextEpisode: nextSeason.episodes.first,
            isSeriesCompleted: false,
            nextSeason: nextSeason,
          );
        }
      }
    } else {
      // Current episode not found in any season; check if we can place it by season number
      for (final season in sortedSeasons) {
        if (season.number > currentSeasonNum && season.episodes.isNotEmpty) {
          return NextEpisodeResult(
            nextEpisode: season.episodes.first,
            isSeriesCompleted: false,
            nextSeason: season,
          );
        }
      }
    }

    // No next episode found -> Series is completed
    return const NextEpisodeResult(isSeriesCompleted: true);
  }

  /// Resolves the previous episode before [currentEpisode] given the available [seasons].
  MediaItem? resolvePrevious({
    required MediaItem currentEpisode,
    required List<SeasonGroup> seasons,
  }) {
    if (seasons.isEmpty) return null;

    final sortedSeasons = normalizeAndSortSeasons(seasons);
    final currentSeasonNum = seasonNumberFor(currentEpisode);
    final currentEpisodeNum = episodeNumberFor(currentEpisode);

    var currentSeasonIndex = sortedSeasons.indexWhere((s) => s.number == currentSeasonNum);
    if (currentSeasonIndex == -1) {
      currentSeasonIndex = sortedSeasons.indexWhere(
        (s) => s.episodes.any((e) => e.id == currentEpisode.id),
      );
    }

    if (currentSeasonIndex != -1) {
      final currentSeason = sortedSeasons[currentSeasonIndex];
      final currentEpIndex = currentSeason.episodes.indexWhere(
        (e) => e.id == currentEpisode.id || episodeNumberFor(e) == currentEpisodeNum,
      );

      // Check if there is a previous episode in the current season
      if (currentEpIndex > 0) {
        return currentSeason.episodes[currentEpIndex - 1];
      }

      // If at the start of the current season, look for the last episode of the preceding season
      for (var sIdx = currentSeasonIndex - 1; sIdx >= 0; sIdx--) {
        final prevSeason = sortedSeasons[sIdx];
        if (prevSeason.episodes.isNotEmpty) {
          return prevSeason.episodes.last;
        }
      }
    }

    return null;
  }
}
