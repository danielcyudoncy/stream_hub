import 'package:get/get.dart';
import '../../data/repositories/subscription_repository.dart';
import '../../data/services/paystack_service.dart';
import '../../data/services/subscription_local_service.dart';
import '../../data/services/subscription_remote_service.dart';
import 'subscription_controller.dart';

class SubscriptionBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<PaystackService>()) {
      Get.lazyPut<PaystackService>(() => PaystackService());
    }
    if (!Get.isRegistered<SubscriptionLocalService>()) {
      Get.lazyPut<SubscriptionLocalService>(() => SubscriptionLocalService());
    }
    if (!Get.isRegistered<SubscriptionRemoteService>()) {
      Get.lazyPut<SubscriptionRemoteService>(() => SubscriptionRemoteService());
    }
    if (!Get.isRegistered<SubscriptionRepository>()) {
      Get.lazyPut<SubscriptionRepository>(() => SubscriptionRepositoryImpl());
    }

    Get.lazyPut<SubscriptionController>(
      () => SubscriptionController(
        subscriptionRepository: Get.find<SubscriptionRepository>(),
      ),
    );
  }
}
