import 'package:get/get.dart';
import '../../core/routes/app_routes.dart';

class AuthController extends GetxController {
  final RxBool isLoading = false.obs;

  void login(String email, String password) async {
    isLoading.value = true;
    await Future.delayed(const Duration(seconds: 1)); // Simulate auth delay
    isLoading.value = false;
    Get.offAllNamed(AppRoutes.dashboard);
  }
}
