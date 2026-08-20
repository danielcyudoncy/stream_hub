import 'package:get/get.dart';
import 'package:stream_hub/core/media/media_library.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../data/repositories/favorite_repository.dart';
import 'series_genre_controller.dart';

class SeriesGenreBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SeriesGenreController>(() => SeriesGenreController(
          catalogRepository: Get.find<CatalogRepository>(),
          mediaLibrary: Get.isRegistered<MediaLibrary>()
              ? Get.find<MediaLibrary>()
              : null,
          favoriteRepository: Get.isRegistered<FavoriteRepository>()
              ? Get.find<FavoriteRepository>()
              : null,
        ));
  }
}
