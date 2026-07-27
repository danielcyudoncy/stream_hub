import 'package:get/get.dart';

class ProviderManagerController extends GetxController {
  final RxList<dynamic> providers = <dynamic>[].obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadProviders();
  }

  void loadProviders() {
    isLoading.value = true;
    // Providers load from database will go here in Phase 2
    isLoading.value = false;
  }
}
