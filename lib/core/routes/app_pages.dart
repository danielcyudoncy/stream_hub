import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'app_routes.dart';
import '../../modules/splash/splash_page.dart';
import '../../modules/splash/splash_binding.dart';
import '../../modules/dashboard/dashboard_page.dart';
import '../../modules/dashboard/dashboard_binding.dart';
import '../../modules/settings/settings_page.dart';
import '../../modules/settings/settings_binding.dart';
import '../../modules/authentication/auth_page.dart';
import '../../modules/authentication/auth_binding.dart';
import '../../modules/provider_manager/provider_manager_page.dart';
import '../../modules/provider_manager/provider_manager_binding.dart';
import '../../shared/widgets/empty_view.dart';

class AppPages {
  static const initial = AppRoutes.splash;

  static final unknownRoute = GetPage(
    name: AppRoutes.unknown,
    page: () => const Scaffold(
      body: EmptyView(
        title: 'Page Not Found',
        description: 'The screen you are trying to access does not exist or has been moved.',
      ),
    ),
  );

  static final pages = [
    GetPage(
      name: AppRoutes.splash,
      page: () => const SplashPage(),
      binding: SplashBinding(),
    ),
    GetPage(
      name: AppRoutes.dashboard,
      page: () => const DashboardPage(),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: AppRoutes.auth,
      page: () => const AuthPage(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: AppRoutes.settings,
      page: () => const SettingsPage(),
      binding: SettingsBinding(),
    ),
    GetPage(
      name: AppRoutes.providerManager,
      page: () => const ProviderManagerPage(),
      binding: ProviderManagerBinding(),
    ),
  ];
}
