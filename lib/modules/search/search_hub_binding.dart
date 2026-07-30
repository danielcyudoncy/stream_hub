import 'package:get/get.dart';
import 'search_hub_controller.dart';

class SearchHubBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<SearchHubController>()) {
      Get.lazyPut<SearchHubController>(() => SearchHubController());
    }
  }
}