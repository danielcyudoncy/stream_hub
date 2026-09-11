import 'package:get/get.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/remote/free_tv_m3u_remote_data_source.dart';
import 'package:stream_hub/data/repositories/free_tv_repository.dart';
import 'package:stream_hub/data/services/free_tv_catalog_builder.dart';
import 'package:stream_hub/data/services/free_tv_service.dart';
import 'package:stream_hub/data/sources/free_tv_sources.dart';
import '../controllers/free_live_tv_controller.dart';

class FreeLiveTvBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<FreeTvService>(
      () => FreeTvService(
        builder: FreeTvCatalogBuilder(
          m3uRemoteDataSource: CustomM3uFreeTvRemoteDataSource(
            source: FreeTvSources.portal5458,
            logger: Get.isRegistered<LoggingService>()
                ? Get.find<LoggingService>()
                : null,
          ),
          logger: Get.isRegistered<LoggingService>()
              ? Get.find<LoggingService>()
              : null,
        ),
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
