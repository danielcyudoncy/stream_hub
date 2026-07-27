import 'package:get/get.dart';
import 'provider_manager_controller.dart';

class ProviderManagerBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ProviderManagerController>(() => ProviderManagerController());
  }
}
