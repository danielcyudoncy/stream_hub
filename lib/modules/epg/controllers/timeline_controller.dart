import 'package:get/get.dart';
import 'package:stream_hub/modules/epg/models/epg_timeline_entry.dart';
import 'package:stream_hub/modules/epg/repositories/timeline_repository.dart';

class TimelineController extends GetxController {
  final TimelineRepository timelineRepository;

  TimelineController({required this.timelineRepository});

  final RxList<EPGTimelineEntry> timelineEntries = <EPGTimelineEntry>[].obs;
  final RxBool isLoading = true.obs;
  final RxString error = ''.obs;
  final Rx<DateTime> windowStart = DateTime.now().obs;
  final Rx<DateTime> windowEnd = DateTime.now().obs;
  final RxString channelId = ''.obs;
  final RxInt timelineWindowHours = 6.obs;

  @override
  void onInit() {
    super.onInit();
    loadTimeline();
  }

  Future<void> loadTimeline() async {
    if (channelId.value.isEmpty) return;
    isLoading.value = true;
    error.value = '';
    try {
      final now = DateTime.now();
      final start = now.subtract(Duration(hours: timelineWindowHours.value ~/ 2));
      final end = now.add(Duration(hours: timelineWindowHours.value ~/ 2));
      windowStart.value = start;
      windowEnd.value = end;

      final entries = await timelineRepository.getTimelineForWindow(
        channelId: channelId.value,
        windowStart: start,
        windowEnd: end,
      );
      timelineEntries.assignAll(entries);
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadTimelineForChannel(String id) async {
    channelId.value = id;
    await loadTimeline();
  }

  void setTimelineWindowHours(int hours) {
    timelineWindowHours.value = hours;
    loadTimeline();
  }

  void scrollToNow() {
    final now = DateTime.now();
    windowStart.value = now.subtract(Duration(hours: timelineWindowHours.value ~/ 2));
    windowEnd.value = now.add(Duration(hours: timelineWindowHours.value ~/ 2));
    loadTimeline();
  }

  void scrollToMorning() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, 6, 0);
    final end = start.add(const Duration(hours: 12));
    windowStart.value = start;
    windowEnd.value = end;
    loadTimeline();
  }

  void scrollToAfternoon() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, 12, 0);
    final end = start.add(const Duration(hours: 12));
    windowStart.value = start;
    windowEnd.value = end;
    loadTimeline();
  }

  void scrollToEvening() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, 18, 0);
    final end = start.add(const Duration(hours: 12));
    windowStart.value = start;
    windowEnd.value = end;
    loadTimeline();
  }

  void scrollToTomorrow() {
    final now = DateTime.now().add(const Duration(days: 1));
    final start = DateTime(now.year, now.month, now.day, 0, 0);
    final end = start.add(const Duration(hours: 24));
    windowStart.value = start;
    windowEnd.value = end;
    loadTimeline();
  }

  void scrollToDate(DateTime date) {
    final start = DateTime(date.year, date.month, date.day, 0, 0);
    final end = start.add(const Duration(hours: 24));
    windowStart.value = start;
    windowEnd.value = end;
    loadTimeline();
  }
}