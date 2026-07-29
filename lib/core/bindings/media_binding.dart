import 'package:get/get.dart';
import 'package:stream_hub/core/media/media_catalog.dart';
import 'package:stream_hub/core/media/default_media_library.dart';
import 'package:stream_hub/core/media/media_engine.dart';
import 'package:stream_hub/core/media/media_library.dart';
import 'package:stream_hub/core/media/media_source_manager.dart';
import 'package:stream_hub/core/media/media_source_factory.dart';
import 'package:stream_hub/data/parsers/m3u_parser.dart';
import 'package:stream_hub/data/repositories/catalog_repository.dart';
import 'package:stream_hub/data/repositories/catalog_repository_impl.dart';
import 'package:stream_hub/data/repositories/media_repository_impl.dart';
import 'package:stream_hub/data/repositories/media_source_repository_impl.dart';
import 'package:stream_hub/data/services/m3u_download_service.dart';
import 'package:stream_hub/data/services/playlist_cache_service.dart';
import 'package:stream_hub/data/services/playlist_statistics_service.dart';
import 'package:stream_hub/data/services/playlist_validation_service.dart';

class MediaBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MediaSourceManager>(() => MediaSourceManager());
    Get.lazyPut<MediaCatalog>(() => MediaCatalog());
    Get.lazyPut<MediaLibrary>(() => DefaultMediaLibrary());
    Get.lazyPut<MediaEngine>(() => DefaultMediaEngine(
          Get.find<MediaCatalog>(),
          Get.find<MediaLibrary>(),
          Get.find<MediaSourceManager>(),
          Get.find<CatalogRepository>(),
        ));
    
    Get.putAsync<PlaylistCacheService>(() => PlaylistCacheService(Get.find()).init());

    Get.lazyPut<M3UDownloadService>(() => M3UDownloadService(Get.find()));
    Get.lazyPut<M3UParser>(() => M3UParser());
    Get.lazyPut<PlaylistCacheService>(() => PlaylistCacheService(Get.find()), fenix: true);
    Get.lazyPut<PlaylistValidationService>(() => PlaylistValidationService(Get.find()));
    Get.lazyPut<PlaylistStatisticsService>(() => PlaylistStatisticsService(Get.find()));
    Get.lazyPut<MediaSourceFactory>(() => DefaultMediaSourceFactory());

    Get.lazyPut<MediaRepositoryImpl>(() => MediaRepositoryImpl(
          Get.find<MediaCatalog>(),
        ));
    Get.lazyPut<MediaSourceRepositoryImpl>(() => MediaSourceRepositoryImpl(
          Get.find<MediaSourceManager>(),
          Get.find(),
        ));
    Get.lazyPut<CatalogRepositoryImpl>(() => CatalogRepositoryImpl(
          Get.find<MediaCatalog>(),
          Get.find<MediaSourceManager>(),
          Get.find(),
        ));
  }
}
