import 'dart:async';
import 'package:get/get.dart';
import 'package:stream_hub/core/media/media_catalog.dart';
import 'package:stream_hub/core/media/default_media_library.dart';
import 'package:stream_hub/core/media/media_engine.dart';
import 'package:stream_hub/core/media/media_library.dart';
import 'package:stream_hub/core/media/media_source_manager.dart';
import 'package:stream_hub/core/media/media_source_factory.dart';
import 'package:stream_hub/core/media/repositories/playback_repository.dart';
import 'package:stream_hub/data/parsers/m3u_parser.dart';
import 'package:stream_hub/data/repositories/catalog_repository.dart';
import 'package:stream_hub/data/repositories/catalog_repository_impl.dart';
import 'package:stream_hub/data/repositories/media_repository_impl.dart';
import 'package:stream_hub/data/repositories/media_source_repository.dart';
import 'package:stream_hub/data/repositories/media_source_repository_impl.dart';
import 'package:stream_hub/data/repositories/playback_repository_impl.dart';
import 'package:stream_hub/data/services/m3u_download_service.dart';
import 'package:stream_hub/data/services/playback_local_service.dart';
import 'package:stream_hub/data/services/playlist_cache_service.dart';
import 'package:stream_hub/data/services/playlist_statistics_service.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/data/services/playlist_validation_service.dart';

class MediaBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MediaSourceManager>(() => MediaSourceManager());
    Get.lazyPut<MediaCatalog>(() => MediaCatalog());
    Get.lazyPut<MediaLibrary>(() => DefaultMediaLibrary());
    Get.lazyPut<MediaEngine>(
      () => DefaultMediaEngine(
        Get.find<MediaCatalog>(),
        Get.find<MediaLibrary>(),
        Get.find<MediaSourceManager>(),
        Get.find<CatalogRepository>(),
      ),
    );

    final playlistCacheService = PlaylistCacheService(Get.find());
    Get.put<PlaylistCacheService>(playlistCacheService, permanent: true);
    unawaited(playlistCacheService.init());

    final playbackLocalService = PlaybackLocalService(
      logger: Get.find<LoggingService>(),
    );
    Get.put<PlaybackLocalService>(playbackLocalService, permanent: true);
    unawaited(playbackLocalService.init());
    Get.put<PlaybackRepository>(
      PlaybackRepositoryImpl(Get.find<PlaybackLocalService>()),
      permanent: true,
    );

    Get.lazyPut<M3UDownloadService>(() => M3UDownloadService(Get.find()));
    Get.lazyPut<M3UParser>(() => M3UParser());
    Get.lazyPut<PlaylistValidationService>(
      () => PlaylistValidationService(Get.find()),
    );
    Get.lazyPut<PlaylistStatisticsService>(
      () => PlaylistStatisticsService(Get.find()),
    );
    Get.lazyPut<MediaSourceFactory>(
      () => DefaultMediaSourceFactory(),
      fenix: true,
    );

    Get.lazyPut<MediaRepositoryImpl>(
      () => MediaRepositoryImpl(Get.find<MediaCatalog>()),
    );
    Get.lazyPut<MediaSourceRepository>(
      () => MediaSourceRepositoryImpl(
        Get.find<MediaSourceManager>(),
        Get.find<LoggingService>(),
      ),
      fenix: true,
    );
    Get.lazyPut<CatalogRepository>(
      () => CatalogRepositoryImpl(
        Get.find<MediaCatalog>(),
        Get.find<MediaSourceManager>(),
        Get.find(),
      ),
      fenix: true,
    );
    Get.lazyPut<CatalogRepositoryImpl>(
      () => Get.find<CatalogRepository>() as CatalogRepositoryImpl,
      fenix: true,
    );
  }
}
