import 'package:get/get.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../data/repositories/history_repository.dart';
import 'search_hub_controller.dart';

class SearchHubBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<SearchHubController>()) {
      Get.lazyPut<SearchHubController>(
        () => SearchHubController(
          catalogRepository: Get.isRegistered<CatalogRepository>()
              ? Get.find<CatalogRepository>()
              : null,
          historyRepository: Get.isRegistered<HistoryRepository>()
              ? Get.find<HistoryRepository>()
              : null,
        ),
      );
    }
  }
}