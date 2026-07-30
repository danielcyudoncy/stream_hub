import 'package:stream_hub/modules/epg/models/epg_timeline_entry.dart';

abstract class TimelineService {
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
}