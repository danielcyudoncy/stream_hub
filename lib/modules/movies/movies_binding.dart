import 'package:get/get.dart';
import 'package:stream_hub/core/media/media_engine.dart';
import 'package:stream_hub/core/media/media_library.dart';
import 'package:stream_hub/data/repositories/catalog_repository.dart';
import 'movies_controller.dart';

class MoviesBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<MoviesController>()) {
      Get.lazyPut<MoviesController>(() => MoviesController(
            mediaEngine: Get.find<MediaEngine>(),
            mediaLibrary: Get.find<MediaLibrary>(),
            catalogRepository: Get.find<CatalogRepository>(),
          ));
    }
  }
}
