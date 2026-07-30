import 'package:get/get.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/player/media_kit_player_adapter.dart';
import 'package:stream_hub/core/media/player/player_adapter.dart';
import 'package:stream_hub/data/repositories/playback_repository_impl.dart';
import 'package:stream_hub/data/repositories/session_repository_impl.dart';
import 'package:stream_hub/data/services/playback_local_service.dart';

class PlayerBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PlayerAdapter>(() => MediaKitPlayerAdapter());
    Get.lazyPut<PlaybackLocalService>(() => PlaybackLocalService());
    Get.lazyPut<PlaybackRepositoryImpl>(() => PlaybackRepositoryImpl(
          Get.find<PlaybackLocalService>(),
        ));
    Get.lazyPut<SessionRepositoryImpl>(() => SessionRepositoryImpl(
          Get.find<PlaybackLocalService>(),
        ));
    Get.put<LoggingService>(LoggingService(), permanent: true);
  }
}
