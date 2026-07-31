import 'package:get/get.dart';
import 'package:stream_hub/core/media/media_engine.dart';
import 'package:stream_hub/core/media/media_library.dart';
import 'package:stream_hub/data/repositories/catalog_repository.dart';
import 'package:stream_hub/data/repositories/favorite_repository.dart';
import '../controllers/live_tv_home_controller.dart';
import '../controllers/live_tv_controller.dart';
import '../controllers/category_controller.dart';
import '../controllers/favorites_controller.dart';
import '../controllers/provider_controller.dart';
import '../controllers/live_tv_library_controller.dart';

class LiveTVBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<LiveTVHomeController>()) {
      Get.lazyPut<LiveTVHomeController>(() => LiveTVHomeController(
            mediaEngine: Get.find<MediaEngine>(),
            mediaLibrary: Get.find<MediaLibrary>(),
            catalogRepository: Get.find<CatalogRepository>(),
          ));
    }
    if (!Get.isRegistered<LiveTVController>()) {
      Get.lazyPut<LiveTVController>(() => LiveTVController(
            mediaEngine: Get.find<MediaEngine>(),
            mediaLibrary: Get.find<MediaLibrary>(),
            catalogRepository: Get.find<CatalogRepository>(),
            favoriteRepository: Get.isRegistered<FavoriteRepository>()
                ? Get.find<FavoriteRepository>()
                : null,
          ));
    }
    if (!Get.isRegistered<CategoryController>()) {
      Get.lazyPut<CategoryController>(() => CategoryController(
            mediaEngine: Get.find<MediaEngine>(),
            mediaLibrary: Get.find<MediaLibrary>(),
            catalogRepository: Get.find<CatalogRepository>(),
          ));
    }
    if (!Get.isRegistered<FavoritesController>()) {
      Get.lazyPut<FavoritesController>(() => FavoritesController(
            mediaEngine: Get.find<MediaEngine>(),
            mediaLibrary: Get.find<MediaLibrary>(),
            catalogRepository: Get.find<CatalogRepository>(),
            favoriteRepository: Get.isRegistered<FavoriteRepository>()
                ? Get.find<FavoriteRepository>()
                : null,
          ));
    }
    if (!Get.isRegistered<ProviderController>()) {
      Get.lazyPut<ProviderController>(() => ProviderController(
            mediaEngine: Get.find<MediaEngine>(),
            mediaLibrary: Get.find<MediaLibrary>(),
            catalogRepository: Get.find<CatalogRepository>(),
          ));
    }
    if (!Get.isRegistered<LiveTVLibraryController>()) {
      Get.lazyPut<LiveTVLibraryController>(() => LiveTVLibraryController(
            mediaEngine: Get.find<MediaEngine>(),
            mediaLibrary: Get.find<MediaLibrary>(),
            catalogRepository: Get.find<CatalogRepository>(),
          ));
    }
  }
}