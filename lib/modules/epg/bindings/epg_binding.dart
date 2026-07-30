import 'package:get/get.dart';
import 'package:stream_hub/modules/epg/controllers/guide_controller.dart';
import 'package:stream_hub/modules/epg/controllers/timeline_controller.dart';
import 'package:stream_hub/modules/epg/controllers/program_controller.dart';
import 'package:stream_hub/modules/epg/controllers/channel_timeline_controller.dart';
import 'package:stream_hub/modules/epg/repositories/guide_repository.dart';
import 'package:stream_hub/modules/epg/repositories/guide_repository_impl.dart';
import 'package:stream_hub/modules/epg/repositories/timeline_repository.dart';
import 'package:stream_hub/modules/epg/repositories/timeline_repository_impl.dart';
import 'package:stream_hub/modules/epg/repositories/program_repository.dart';
import 'package:stream_hub/modules/epg/repositories/program_repository_impl.dart';

class EPGBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<GuideRepository>(() => GuideRepositoryImpl());
    Get.lazyPut<TimelineRepository>(() => TimelineRepositoryImpl());
    Get.lazyPut<ProgramRepository>(() => ProgramRepositoryImpl());

    Get.lazyPut<GuideController>(() => GuideController(
          guideRepository: Get.find<GuideRepository>(),
        ));
    Get.lazyPut<TimelineController>(() => TimelineController(
          timelineRepository: Get.find<TimelineRepository>(),
        ));
    Get.lazyPut<ProgramController>(() => ProgramController(
          programRepository: Get.find<ProgramRepository>(),
        ));
    Get.lazyPut<ChannelTimelineController>(() => ChannelTimelineController(
          timelineRepository: Get.find<TimelineRepository>(),
        ));
  }
}