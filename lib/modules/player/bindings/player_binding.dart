import 'package:get/get.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/repositories/playback_repository.dart';
import 'package:stream_hub/core/streaming/repositories/stream_repository.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/repositories/catalog_repository.dart';
import 'package:stream_hub/data/repositories/favorite_repository.dart';
import 'package:stream_hub/data/repositories/history_repository.dart';
import 'package:stream_hub/data/repositories/session_repository_impl.dart';
import 'package:stream_hub/data/services/playback_local_service.dart';
import '../controllers/player_controller.dart';

class PlayerBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SessionRepositoryImpl>(() => SessionRepositoryImpl(
          Get.find<PlaybackLocalService>(),
        ));
    Get.put<LoggingService>(LoggingService(), permanent: true);

    Get.create<PlayerController>(() {
      final args = Get.arguments is Map ? Get.arguments as Map : null;
      final rawItems = args?['items'];
      final items = rawItems is List ? rawItems : [];
      final currentId = args?['currentId']?.toString();
      final itemId = args?['itemId']?.toString();
      final streamUrl = args?['streamUrl']?.toString();
      final resumePosition = args?['resumePosition'] is Duration
          ? args!['resumePosition'] as Duration
          : null;

      // Items are passed via pendingItems/pendingCurrentId so that onInit —
      // which runs after the binding factory returns — can call setChannelList
      // once settings are loaded and the playback event listener is registered.
      // Calling setChannelList directly here would fire before onInit, losing
      // all early loading/buffering/error events and using unapplied defaults.
      return PlayerController(
        itemId: itemId,
        streamUrl: streamUrl,
        resumePosition: resumePosition,
        pendingItems: items.cast<MediaItem>(),
        pendingCurrentId: currentId,
        streamRepository: Get.find<StreamRepository>(),
        historyRepository: Get.isRegistered<HistoryRepository>()
            ? Get.find<HistoryRepository>()
            : null,
        favoriteRepository: Get.isRegistered<FavoriteRepository>()
            ? Get.find<FavoriteRepository>()
            : null,
        playbackRepository: Get.isRegistered<PlaybackRepository>()
            ? Get.find<PlaybackRepository>()
            : null,
        catalogRepository: Get.isRegistered<CatalogRepository>()
            ? Get.find<CatalogRepository>()
            : null,
      );
    });
  }
}
