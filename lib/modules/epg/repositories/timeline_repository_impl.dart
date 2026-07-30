import 'package:stream_hub/modules/epg/models/epg_timeline_entry.dart';
import 'package:stream_hub/modules/epg/repositories/timeline_repository.dart';

class TimelineRepositoryImpl implements TimelineRepository {
  @override
  Future<List<EPGTimelineEntry>> getTimeline({
    required String channelId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    await Future.delayed(const Duration(milliseconds: 50));
    return [];
  }

  @override
  Future<List<EPGTimelineEntry>> getCurrentTimeline({
    required String channelId,
  }) async {
    return [];
  }

  @override
  Future<List<EPGTimelineEntry>> getFutureTimeline({
    required String channelId,
    DateTime? fromDate,
  }) async {
    return [];
  }

  @override
  Future<List<EPGTimelineEntry>> getPastTimeline({
    required String channelId,
    DateTime? untilDate,
  }) async {
    return [];
  }

  @override
  Future<List<EPGTimelineEntry>> getTimelineForWindow({
    required String channelId,
    required DateTime windowStart,
    required DateTime windowEnd,
  }) async {
    await Future.delayed(const Duration(milliseconds: 50));
    return [];
  }

  @override
  Future<void> cacheTimeline({
    required String channelId,
    required List<EPGTimelineEntry> entries,
  }) async {
    // Cache implementation placeholder
  }

  @override
  Future<List<EPGTimelineEntry>?> getCachedTimeline({
    required String channelId,
  }) async {
    return null;
  }
}