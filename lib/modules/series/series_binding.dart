import 'package:get/get.dart';
import 'package:stream_hub/core/media/media_engine.dart';
import 'package:stream_hub/core/media/media_library.dart';
import 'package:stream_hub/data/repositories/catalog_repository.dart';
import 'series_controller.dart';

class SeriesBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<SeriesController>()) {
      Get.lazyPut<SeriesController>(() => SeriesController(
            mediaEngine: Get.find<MediaEngine>(),
            mediaLibrary: Get.find<MediaLibrary>(),
            catalogRepository: Get.find<CatalogRepository>(),
          ));
    }
  }
}
