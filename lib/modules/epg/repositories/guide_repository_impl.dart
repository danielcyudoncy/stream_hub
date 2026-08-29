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
      final todayMidnight = DateTime(now.year, now.month, now.day);
      final scheduleTemplates = [
        {'title': 'Morning Live', 'durationHours': 2, 'desc': 'Morning live broadcast and daily highlights.'},
        {'title': 'Daytime Express', 'durationHours': 2, 'desc': 'Daytime program schedule and entertainment.'},
        {'title': 'News & Current Affairs', 'durationHours': 1, 'desc': 'Comprehensive news and live coverage.'},
        {'title': 'Prime Showcase', 'durationHours': 2, 'desc': 'Prime time entertainment and special features.'},
        {'title': 'Live Feature Broadcast', 'durationHours': 2, 'desc': 'Live studio broadcast and special event coverage.'},
        {'title': 'Evening Special', 'durationHours': 2, 'desc': 'Evening prime programming and recap.'},
        {'title': 'Night Edition', 'durationHours': 3, 'desc': 'Late night programming and international broadcast.'},
      ];

      final realPrograms = await catalogRepository!.getByType(MediaType.program);
      final Map<String, List<EPGProgram>> realProgramsByChannel = {};

      if (realPrograms.isNotEmpty) {
        for (final rp in realPrograms) {
          final sTime = rp.metadata['startTime'] != null ? DateTime.tryParse(rp.metadata['startTime'].toString()) : null;
          final eTime = rp.metadata['endTime'] != null ? DateTime.tryParse(rp.metadata['endTime'].toString()) : null;
          final chId = rp.metadata['channelId']?.toString() ?? rp.subtitle;
          if (sTime != null && eTime != null && chId != null) {
            realProgramsByChannel.putIfAbsent(chId, () => []).add(EPGProgram(
              id: rp.id,
              providerId: rp.providerId,
              providerType: rp.providerType,
              title: rp.title,
              mediaType: rp.mediaType,
              createdAt: rp.createdAt,
              updatedAt: rp.updatedAt,
              channelId: chId,
              startTime: sTime,
              endTime: eTime,
              description: rp.description,
              isLive: !now.isBefore(sTime) && now.isBefore(eTime),
            ));
          }
        }
      }

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

        final channelRealPrograms = realProgramsByChannel[channel.id];
        if (channelRealPrograms != null && channelRealPrograms.isNotEmpty) {
          programs.addAll(channelRealPrograms);
        } else {
          // Generate clean round-hour schedule blocks for the day and next day
          var slotStart = todayMidnight;
          int progIdx = 0;
          while (slotStart.isBefore(todayMidnight.add(const Duration(hours: 36)))) {
            final template = scheduleTemplates[progIdx % scheduleTemplates.length];
            final durationHours = template['durationHours'] as int;
            final slotEnd = slotStart.add(Duration(hours: durationHours));

            programs.add(EPGProgram(
              id: 'prog_${channel.id}_$progIdx',
              providerId: channel.providerId,
              providerType: channel.providerType,
              title: '${channel.title}: ${template['title']}',
              mediaType: MediaType.program,
              createdAt: now,
              updatedAt: now,
              channelId: channel.id,
              startTime: slotStart,
              endTime: slotEnd,
              description: template['desc'] as String,
              isLive: !now.isBefore(slotStart) && now.isBefore(slotEnd),
            ));

            slotStart = slotEnd;
            progIdx++;
          }
        }
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