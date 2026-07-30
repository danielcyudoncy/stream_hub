import 'package:get/get.dart';
import 'package:stream_hub/core/media/media_engine.dart';
import 'package:stream_hub/core/media/media_library.dart';
import 'package:stream_hub/data/repositories/catalog_repository.dart';
import 'package:stream_hub/data/repositories/history_repository.dart';
import 'package:stream_hub/data/repositories/favorite_repository.dart';
import 'library_controller.dart';

class LibraryBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<LibraryController>()) {
      Get.lazyPut<LibraryController>(() => LibraryController(
            mediaEngine: Get.find<MediaEngine>(),
            mediaLibrary: Get.find<MediaLibrary>(),
            catalogRepository: Get.find<CatalogRepository>(),
            historyRepository: Get.find<HistoryRepository>(),
            favoriteRepository: Get.find<FavoriteRepository>(),
          ));
    }
  }
}