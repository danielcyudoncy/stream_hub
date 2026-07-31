import 'package:get/get.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/player/media_kit_player_adapter.dart';
import 'package:stream_hub/core/media/player/player_adapter.dart';
import 'package:stream_hub/core/media/stream_resolver.dart';
import 'package:stream_hub/core/media/stream_resolvers/m3u_stream_resolver.dart';
import 'package:stream_hub/data/repositories/favorite_repository.dart';
import 'package:stream_hub/data/repositories/history_repository.dart';
import 'package:stream_hub/data/repositories/playback_repository_impl.dart';
import 'package:stream_hub/data/repositories/session_repository_impl.dart';
import 'package:stream_hub/data/services/playback_local_service.dart';
import '../controllers/player_controller.dart';

class PlayerBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PlayerAdapter>(() => MediaKitPlayerAdapter());
    Get.lazyPut<StreamResolver>(() => M3UStreamResolver());
    Get.lazyPut<PlaybackLocalService>(() => PlaybackLocalService());
    Get.lazyPut<PlaybackRepositoryImpl>(() => PlaybackRepositoryImpl(
          Get.find<PlaybackLocalService>(),
        ));
    Get.lazyPut<SessionRepositoryImpl>(() => SessionRepositoryImpl(
          Get.find<PlaybackLocalService>(),
        ));
    Get.put<LoggingService>(LoggingService(), permanent: true);

    Get.create<PlayerController>(() {
      final args = Get.arguments as Map<String, dynamic>?;
      final items = args?['items'] as List? ?? [];
      final currentId = args?['currentId'] as String?;
      final itemId = args?['itemId'] as String?;
      final streamUrl = args?['streamUrl'] as String?;

      final controller = PlayerController(
        itemId: itemId,
        streamUrl: streamUrl,
        adapter: Get.find<PlayerAdapter>(),
        streamResolver: Get.find<StreamResolver>(),
        historyRepository: Get.find<HistoryRepository>(),
        favoriteRepository: Get.find<FavoriteRepository>(),
      );

      if (items.isNotEmpty) {
        controller.setChannelList(
          items.cast(),
          currentId: currentId,
        );
      }

      return controller;
    });
  }
}
