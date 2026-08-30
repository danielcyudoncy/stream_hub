import 'package:get/get.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/repositories/free_tv_repository.dart';
import 'package:stream_hub/data/services/free_tv_service.dart';
import '../controllers/free_live_tv_controller.dart';

class FreeLiveTvBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<FreeTvService>(
      () => FreeTvService(
        logger: Get.isRegistered<LoggingService>()
            ? Get.find<LoggingService>()
            : null,
      ),
    );

    Get.lazyPut<FreeTvRepository>(
      () => FreeTvRepository(
        service: Get.find<FreeTvService>(),
        logger: Get.isRegistered<LoggingService>()
            ? Get.find<LoggingService>()
            : null,
      ),
    );

    Get.lazyPut<FreeLiveTvController>(
      () => FreeLiveTvController(
        repository: Get.find<FreeTvRepository>(),
        logger: Get.isRegistered<LoggingService>()
            ? Get.find<LoggingService>()
            : null,
      ),
    );
  }
}
