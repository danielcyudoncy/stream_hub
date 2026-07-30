import 'package:stream_hub/modules/epg/models/epg_program.dart';
import 'package:stream_hub/modules/epg/repositories/program_repository.dart';

class ProgramRepositoryImpl implements ProgramRepository {
  @override
  Future<EPGProgram?> getProgramById(String programId) async {
    await Future.delayed(const Duration(milliseconds: 50));
    return null;
  }

  @override
  Future<List<EPGProgram>> getProgramsByChannel(String channelId) async {
    return [];
  }

  @override
  Future<List<EPGProgram>> searchPrograms(String query) async {
    return [];
  }

  @override
  Future<List<EPGProgram>> getProgramsByGenre(String genre) async {
    return [];
  }

  @override
  Future<List<EPGProgram>> getProgramsByCategory(String category) async {
    return [];
  }

  @override
  Future<List<EPGProgram>> getProgramsByLanguage(String language) async {
    return [];
  }

  @override
  Future<List<EPGProgram>> getProgramsByCountry(String country) async {
    return [];
  }

  @override
  Future<List<EPGProgram>> getCurrentlyPlaying() async {
    return [];
  }

  @override
  Future<List<EPGProgram>> getUpcoming({int limit = 20}) async {
    return [];
  }

  @override
  Future<List<EPGProgram>> getProgramsByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return [];
  }

  @override
  Future<void> cacheProgram(EPGProgram program) async {
    // Cache implementation placeholder
  }

  @override
  Future<void> cachePrograms(List<EPGProgram> programs) async {
    // Cache implementation placeholder
  }
}