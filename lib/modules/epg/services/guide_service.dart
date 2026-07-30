import 'package:stream_hub/modules/epg/models/epg_guide.dart';
import 'package:stream_hub/modules/epg/models/epg_program.dart';

abstract class GuideService {
  Future<EPGGuide> fetchGuide({
    required String sourceId,
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<void> refreshGuide({
    required String sourceId,
  });

  Future<EPGGuide?> getCachedGuide({
    required String sourceId,
  });

  Future<List<EPGProgram>> searchPrograms({
    required String query,
    String? sourceId,
  });

  Future<List<EPGProgram>> getProgramsByChannel({
    required String channelId,
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<List<EPGProgram>> getProgramsByDateRange({
    required String channelId,
    required DateTime startDate,
    required DateTime endDate,
  });

  Future<List<String>> getCategories({
    String? sourceId,
  });

  Future<List<String>> getLanguages({
    String? sourceId,
  });

  Future<List<String>> getCountries({
    String? sourceId,
  });
}