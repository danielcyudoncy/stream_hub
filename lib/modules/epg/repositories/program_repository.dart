import 'package:stream_hub/modules/epg/models/epg_program.dart';

abstract class ProgramRepository {
  Future<EPGProgram?> getProgramById(String programId);

  Future<List<EPGProgram>> getProgramsByChannel(String channelId);

  Future<List<EPGProgram>> searchPrograms(String query);

  Future<List<EPGProgram>> getProgramsByGenre(String genre);

  Future<List<EPGProgram>> getProgramsByCategory(String category);

  Future<List<EPGProgram>> getProgramsByLanguage(String language);

  Future<List<EPGProgram>> getProgramsByCountry(String country);

  Future<List<EPGProgram>> getCurrentlyPlaying();

  Future<List<EPGProgram>> getUpcoming({
    int limit = 20,
  });

  Future<List<EPGProgram>> getProgramsByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  });

  Future<void> cacheProgram(EPGProgram program);

  Future<void> cachePrograms(List<EPGProgram> programs);
}