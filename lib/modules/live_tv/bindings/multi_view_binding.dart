import 'package:get/get.dart';
import 'package:stream_hub/core/media/media_engine.dart';
import 'package:stream_hub/core/media/media_library.dart';
import 'package:stream_hub/data/repositories/catalog_repository.dart';
import '../controllers/multi_view_controller.dart';

class MultiViewBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MultiViewController>(() => MultiViewController(
          catalogRepository: Get.find<CatalogRepository>(),
          mediaEngine: Get.find<MediaEngine>(),
          mediaLibrary: Get.find<MediaLibrary>(),
        ));
  }
}
