import 'package:get/get.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/repositories/download_repository.dart';
import 'package:stream_hub/core/services/download_service.dart';
import 'package:stream_hub/data/repositories/download_repository_impl.dart';
import 'package:stream_hub/data/services/database_service.dart';
import 'package:stream_hub/modules/downloads/controllers/downloads_controller.dart';

class DownloadsBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<DownloadRepository>()) {
      Get.lazyPut<DownloadRepository>(
        () => DownloadRepositoryImpl(
          databaseService: Get.isRegistered<DatabaseService>()
              ? Get.find<DatabaseService>()
              : null,
          logger: Get.isRegistered<LoggingService>()
              ? Get.find<LoggingService>()
              : null,
        ),
      );
    }

    if (!Get.isRegistered<DownloadService>()) {
      Get.lazyPut<DownloadService>(
        () => DownloadService(
          repository: Get.find<DownloadRepository>(),
          logger: Get.isRegistered<LoggingService>()
              ? Get.find<LoggingService>()
              : null,
        ),
      );
    }

    Get.lazyPut<DownloadsController>(
      () => DownloadsController(
        repository: Get.find<DownloadRepository>(),
        service: Get.find<DownloadService>(),
      ),
    );
  }
}
