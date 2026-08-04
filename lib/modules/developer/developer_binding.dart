import 'package:get/get.dart';
import 'package:stream_hub/core/bindings/iptv_core_binding.dart';
import 'package:stream_hub/core/iptv/iptv_core.dart';
import 'developer_controller.dart';
import 'pages/playback_test_controller.dart';
import 'pages/provider_test_controller.dart';
import 'pages/stream_test_controller.dart';

class DeveloperBinding extends Bindings {
  @override
  void dependencies() {
    IptvCoreBinding().dependencies();
    if (Get.isRegistered<DeveloperController>()) return;
    Get.lazyPut<DeveloperController>(
      () => DeveloperController(Get.find<IptvCore>()),
    );
    Get.lazyPut<PlaybackTestController>(() => PlaybackTestController());
    Get.lazyPut<ProviderTestController>(() => ProviderTestController());
    Get.lazyPut<StreamTestController>(() => StreamTestController());
  }
}
