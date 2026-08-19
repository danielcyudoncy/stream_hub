import 'package:get/get.dart';
import '../../../core/media/media_library.dart';
import '../../../core/media/repositories/playback_repository.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../data/repositories/favorite_repository.dart';
import 'movie_details_controller.dart';

class MovieDetailsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MovieDetailsController>(
      () => MovieDetailsController(
        catalogRepository: Get.find<CatalogRepository>(),
        favoriteRepository: Get.find<FavoriteRepository>(),
        playbackRepository: Get.find<PlaybackRepository>(),
        mediaLibrary: Get.find<MediaLibrary>(),
      ),
    );
  }
}
