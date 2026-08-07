import 'package:get/get.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/repositories/playback_repository.dart';
import 'package:stream_hub/core/streaming/repositories/stream_repository.dart';
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
      final args = Get.arguments as Map<String, dynamic>?;
      final items = args?['items'] as List? ?? [];
      final currentId = args?['currentId'] as String?;
      final itemId = args?['itemId'] as String?;
      final streamUrl = args?['streamUrl'] as String?;

      final controller = PlayerController(
        itemId: itemId,
        streamUrl: streamUrl,
        streamRepository: Get.find<StreamRepository>(),
        historyRepository: Get.find<HistoryRepository>(),
        favoriteRepository: Get.find<FavoriteRepository>(),
        playbackRepository: Get.isRegistered<PlaybackRepository>()
            ? Get.find<PlaybackRepository>()
            : null,
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
