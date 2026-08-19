import 'package:get/get.dart';
import '../../../core/media/media_library.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../data/repositories/favorite_repository.dart';
import 'movie_genre_controller.dart';

class MovieGenreBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MovieGenreController>(
      () => MovieGenreController(
        catalogRepository: Get.find<CatalogRepository>(),
        favoriteRepository: Get.isRegistered<FavoriteRepository>()
            ? Get.find<FavoriteRepository>()
            : null,
        mediaLibrary: Get.find<MediaLibrary>(),
      ),
    );
  }
}
