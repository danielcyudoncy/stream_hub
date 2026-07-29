import 'package:get/get.dart';
import '../controllers/home_controller.dart';
import '../controllers/live_tv_controller.dart';
import '../controllers/category_controller.dart';
import '../controllers/favorites_controller.dart';
import '../controllers/provider_controller.dart';
import '../controllers/library_controller.dart';

class LiveTVBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<HomeController>()) {
      Get.lazyPut<HomeController>(() => Get.find<HomeController>());
    }
    if (!Get.isRegistered<LiveTVController>()) {
      Get.lazyPut<LiveTVController>(() => Get.find<LiveTVController>());
    }
    if (!Get.isRegistered<CategoryController>()) {
      Get.lazyPut<CategoryController>(() => Get.find<CategoryController>());
    }
    if (!Get.isRegistered<FavoritesController>()) {
      Get.lazyPut<FavoritesController>(() => Get.find<FavoritesController>());
    }
    if (!Get.isRegistered<ProviderController>()) {
      Get.lazyPut<ProviderController>(() => Get.find<ProviderController>());
    }
    if (!Get.isRegistered<LibraryController>()) {
      Get.lazyPut<LibraryController>(() => Get.find<LibraryController>());
    }
  }
}