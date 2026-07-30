import 'package:get/get.dart';
import 'package:stream_hub/modules/epg/models/epg_timeline_entry.dart';
import 'package:stream_hub/modules/epg/repositories/timeline_repository.dart';

class ChannelTimelineController extends GetxController {
  final TimelineRepository timelineRepository;

  ChannelTimelineController({required this.timelineRepository});

  final RxString channelId = ''.obs;
  final RxString channelName = ''.obs;
  final RxList<EPGTimelineEntry> timelineEntries = <EPGTimelineEntry>[].obs;
  final RxBool isLoading = true.obs;
  final RxBool isLoadingMore = false.obs;
  final RxString error = ''.obs;
  final Rx<DateTime> currentDate = DateTime.now().obs;
  final RxInt visibleHours = 24.obs;

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
      final start = DateTime(currentDate.value.year, currentDate.value.month, currentDate.value.day, 0, 0);
      final end = start.add(const Duration(hours: 24));
      visibleHours.value = 24;

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

  Future<void> loadMore() async {
    if (isLoadingMore.value) return;
    isLoadingMore.value = true;
    try {
      final lastEntry = timelineEntries.isNotEmpty ? timelineEntries.last : null;
      if (lastEntry == null) return;
      final newStart = lastEntry.slotEnd;
      final newEnd = newStart.add(Duration(hours: visibleHours.value));
      final entries = await timelineRepository.getTimelineForWindow(
        channelId: channelId.value,
        windowStart: newStart,
        windowEnd: newEnd,
      );
      timelineEntries.addAll(entries);
    } finally {
      isLoadingMore.value = false;
    }
  }

  void setChannel(String id, String name) {
    channelId.value = id;
    channelName.value = name;
    currentDate.value = DateTime.now();
    loadTimeline();
  }

  void scrollToNow() {
    currentDate.value = DateTime.now();
    loadTimeline();
  }

  void scrollToDate(DateTime date) {
    currentDate.value = date;
    loadTimeline();
  }

  Future<void> scrollToPast() async {
    final start = currentDate.value.subtract(Duration(hours: visibleHours.value));
    final end = currentDate.value;
    timelineEntries.clear();
    isLoading.value = true;
    error.value = '';
    try {
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

  Future<void> scrollToFuture() async {
    final start = currentDate.value;
    final end = currentDate.value.add(Duration(hours: visibleHours.value));
    timelineEntries.clear();
    isLoading.value = true;
    error.value = '';
    try {
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
}