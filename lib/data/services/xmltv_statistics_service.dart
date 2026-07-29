import 'package:stream_hub/data/models/xmltv_models.dart';

class XMLTVStatisticsService {
  XMLTVStatisticsService();

  XMLTVStatistics calculateStatistics(XMLTVGuide guide) {
    final programs = guide.programs;
    final channels = guide.channels;

    final categories = guide.categories.length;
    final languages = guide.languages.length;
    final ratings = guide.ratings.length;

    int duplicateCount = 0;
    final seenProgramIds = <String>{};
    for (final program in programs) {
      if (seenProgramIds.contains(program.id)) {
        duplicateCount++;
      } else {
        seenProgramIds.add(program.id);
      }
    }

    final matchedChannels = channels.where((c) => c.iconUrl != null).length;
    final unmatchedChannels = channels.length - matchedChannels;

    return XMLTVStatistics(
      totalPrograms: programs.length,
      totalChannels: channels.length,
      matchedChannels: matchedChannels,
      unmatchedChannels: unmatchedChannels,
      missingChannels: 0,
      duplicatePrograms: duplicateCount,
      categories: categories,
      languages: languages,
      ratings: ratings,
      syncDuration: Duration.zero,
      lastSync: DateTime.now(),
      guideSizeBytes: guide.sizeBytes ?? 0,
      guideVersion: guide.version,
    );
  }
}