import 'package:get/get.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/streaming/series/xtream_series_info_service.dart';
import 'package:stream_hub/core/streaming/session/session_manager.dart';
import 'package:stream_hub/core/media/repositories/playback_repository.dart';
import 'package:stream_hub/data/repositories/catalog_repository.dart';
import 'package:stream_hub/data/repositories/favorite_repository.dart';
import 'package:stream_hub/data/repositories/provider_repository.dart';
import 'series_details_controller.dart';

class SeriesDetailsBinding extends Bindings {
  @override
  void dependencies() {
    Get.create<SeriesDetailsController>(
      () => SeriesDetailsController(
        sessionManager: Get.find<SessionManager>(),
        providerRepository: Get.find<ProviderRepository>(),
        catalogRepository: Get.find<CatalogRepository>(),
        seriesInfoService: Get.find<XtreamSeriesInfoService>(),
        favoriteRepository: Get.isRegistered<FavoriteRepository>()
            ? Get.find<FavoriteRepository>()
            : null,
        playbackRepository: Get.isRegistered<PlaybackRepository>()
            ? Get.find<PlaybackRepository>()
            : null,
        logger: Get.find<LoggingService>(),
      ),
    );
  }
}

