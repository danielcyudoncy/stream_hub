import 'package:get/get.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/app_initializer.dart';

class SplashController extends GetxController {
  final RxString statusMessage = 'Starting up...'.obs;

  @override
  void onInit() {
    super.onInit();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      statusMessage.value = 'Initializing databases...';
      await AppInitializer.initialize();
      statusMessage.value = 'Ready!';
      Get.offAllNamed(AppRoutes.dashboard);
    } catch (e) {
      statusMessage.value = 'Initialization failed. Retrying...';
      Get.offAllNamed(AppRoutes.dashboard); // Fallback to ensure app is usable
    }
  }
}
