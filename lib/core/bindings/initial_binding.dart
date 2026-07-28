import 'package:get/get.dart';
import '../logging/logging_service.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<LoggingService>()) {
      Get.put<LoggingService>(LoggingService(), permanent: true);
    }
  }
}
