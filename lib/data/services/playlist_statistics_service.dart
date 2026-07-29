import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/models/m3u_models.dart';

class PlaylistStatisticsService {
  final LoggingService _logger;

  PlaylistStatisticsService(this._logger);

  M3UStatistics calculateStatistics(M3UPlaylistResult playlist, Duration syncDuration) {
    final radioCount = playlist.channels.where((c) => c.isRadio).length;
    final tvCount = playlist.channels.length - radioCount;

    final stats = M3UStatistics(
      totalItems: playlist.channels.length,
      channels: tvCount,
      radioCount: radioCount,
      categories: playlist.groups.length,
      languages: playlist.languages.length,
      countries: playlist.countries.length,
      invalidEntries: playlist.invalidEntries,
      duplicates: playlist.duplicateEntries,
      syncDuration: syncDuration,
      lastSync: DateTime.now(),
    );

    _logger.info(
      'Playlist statistics calculated: ${stats.totalItems} items, '
      '${stats.channels} TV, ${stats.radioCount} radio, '
      '${stats.categories} groups',
      tag: 'PlaylistStatisticsService',
    );

    return stats;
  }

  Map<String, dynamic> toHealthData(M3UStatistics stats) {
    return {
      'lastDownload': stats.lastSync.toIso8601String(),
      'playlistSize': stats.totalItems,
      'channelCount': stats.channels + stats.radioCount,
      'responseTime': stats.syncDuration.inMilliseconds,
      'errors': stats.invalidEntries + stats.duplicates,
      'groups': stats.categories,
      'languages': stats.languages,
      'countries': stats.countries,
    };
  }
}
