import 'package:get/get.dart';
import 'package:stream_hub/core/media/media_catalog.dart';
import 'package:stream_hub/core/media/default_media_library.dart';
import 'package:stream_hub/core/media/media_engine.dart';
import 'package:stream_hub/core/media/media_library.dart';
import 'package:stream_hub/core/media/media_source_manager.dart';

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
        ));
  }
}
