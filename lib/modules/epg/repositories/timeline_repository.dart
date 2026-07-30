import 'package:stream_hub/modules/epg/models/epg_timeline_entry.dart';

abstract class TimelineRepository {
  Future<List<EPGTimelineEntry>> getTimeline({
    required String channelId,
    required DateTime startDate,
    required DateTime endDate,
  });

  Future<List<EPGTimelineEntry>> getCurrentTimeline({
    required String channelId,
  });

  Future<List<EPGTimelineEntry>> getFutureTimeline({
    required String channelId,
    DateTime? fromDate,
  });

  Future<List<EPGTimelineEntry>> getPastTimeline({
    required String channelId,
    DateTime? untilDate,
  });

  Future<List<EPGTimelineEntry>> getTimelineForWindow({
    required String channelId,
    required DateTime windowStart,
    required DateTime windowEnd,
  });

  Future<void> cacheTimeline({
    required String channelId,
    required List<EPGTimelineEntry> entries,
  });

  Future<List<EPGTimelineEntry>?> getCachedTimeline({
    required String channelId,
  });
}