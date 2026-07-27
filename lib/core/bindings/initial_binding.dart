import 'package:get/get.dart';
import '../logging/logging_service.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    // Inject core services (if not already injected by AppInitializer)
    if (!Get.isRegistered<LoggingService>()) {
      Get.put<LoggingService>(LoggingService(), permanent: true);
    }
  }
}
