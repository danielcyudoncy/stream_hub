import 'package:stream_hub/modules/epg/models/epg_guide.dart';
import 'package:stream_hub/modules/epg/models/epg_program.dart';
import 'package:stream_hub/modules/epg/repositories/guide_repository.dart';
import 'package:stream_hub/data/repositories/catalog_repository.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/modules/epg/models/epg_channel.dart';

class GuideRepositoryImpl implements GuideRepository {
  final CatalogRepository? catalogRepository;

  GuideRepositoryImpl({this.catalogRepository});

  @override
  Future<EPGGuide> fetchGuide({
    required String sourceId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    
    List<EPGChannel> channels = [];
    List<EPGProgram> programs = [];

    if (catalogRepository != null) {
      final items = await catalogRepository!.getByType(MediaType.channel);
      final now = DateTime.now();

      for (var item in items) {
        final channel = EPGChannel(
          id: item.id,
          providerId: item.providerId,
          providerType: item.providerType,
          title: item.title,
          mediaType: item.mediaType,
          poster: item.poster,
          thumbnail: item.thumbnail,
          createdAt: item.createdAt,
          updatedAt: item.updatedAt,
          number: item.metadata['number']?.toString(),
        );
        channels.add(channel);

        // Generate a single dummy program for the channel covering 24 hours
        var currentStart = now.subtract(const Duration(hours: 2));
        var currentEnd = currentStart.add(const Duration(hours: 24));
        programs.add(EPGProgram(
          id: 'prog_${channel.id}_0',
          providerId: channel.providerId,
          providerType: channel.providerType,
          title: 'No Guide Data for ${channel.title}',
          mediaType: MediaType.program,
          createdAt: now,
          updatedAt: now,
          channelId: channel.id,
          startTime: currentStart,
          endTime: currentEnd,
          description: 'No EPG data is available for this channel at the moment.',
        ));
      }
    }

    return EPGGuide(
      sourceId: sourceId,
      channels: channels,
      programs: programs,
      generatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> cacheGuide(EPGGuide guide) async {
    // Cache implementation placeholder
  }

  @override
  Future<EPGGuide?> getCachedGuide({required String sourceId}) async {
    return null;
  }

  @override
  Future<void> clearCache({String? sourceId}) async {
    // Cache clear implementation placeholder
  }

  @override
  Future<List<EPGProgram>> searchPrograms({
    required String query,
    String? sourceId,
  }) async {
    return [];
  }

  @override
  Future<List<EPGProgram>> getProgramsByChannel({
    required String channelId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return [];
  }

  @override
  Future<List<EPGProgram>> getProgramsByDateRange({
    required String channelId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return [];
  }

  @override
  Future<List<String>> getCategories({String? sourceId}) async {
    return [];
  }

  @override
  Future<List<String>> getLanguages({String? sourceId}) async {
    return [];
  }

  @override
  Future<List<String>> getCountries({String? sourceId}) async {
    return [];
  }
}