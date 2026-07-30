import 'package:get/get.dart';
import 'package:stream_hub/modules/epg/models/epg_program.dart';
import 'package:stream_hub/modules/epg/repositories/program_repository.dart';

class ProgramController extends GetxController {
  final ProgramRepository programRepository;

  ProgramController({required this.programRepository});

  final Rx<EPGProgram?> selectedProgram = Rx<EPGProgram?>(null);
  final RxList<EPGProgram> relatedPrograms = <EPGProgram>[].obs;
  final RxList<EPGProgram> channelPrograms = <EPGProgram>[].obs;
  final RxBool isLoading = true.obs;
  final RxBool isRefreshing = false.obs;
  final RxString error = ''.obs;

  Future<void> loadProgram(String programId) async {
    isLoading.value = true;
    error.value = '';
    try {
      final program = await programRepository.getProgramById(programId);
      selectedProgram.value = program;
      if (program != null && program.channelId != null) {
        await loadChannelPrograms(program.channelId!);
      }
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadChannelPrograms(String channelId) async {
    try {
      final programs = await programRepository.getProgramsByChannel(channelId);
      channelPrograms.assignAll(programs);
    } catch (_) {
      channelPrograms.clear();
    }
  }

  Future<void> refreshProgram(String programId) async {
    isRefreshing.value = true;
    try {
      await loadProgram(programId);
    } finally {
      isRefreshing.value = false;
    }
  }

  List<EPGProgram> getUpcomingPrograms(int limit) {
    final now = DateTime.now();
    final upcoming = channelPrograms
        .where((p) => p.startTime.isAfter(now))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    return upcoming.take(limit).toList();
  }

  EPGProgram? get currentProgram {
    final now = DateTime.now();
    return channelPrograms.firstWhereOrNull(
      (p) => !now.isBefore(p.startTime) && now.isBefore(p.endTime),
    );
  }

  EPGProgram? get nextProgram {
    final now = DateTime.now();
    final upcoming = channelPrograms
        .where((p) => p.startTime.isAfter(now))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    return upcoming.isNotEmpty ? upcoming.first : null;
  }
}