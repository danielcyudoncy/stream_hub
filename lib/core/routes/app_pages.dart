import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'app_routes.dart';
import '../../modules/splash/splash_page.dart';
import '../../modules/splash/splash_binding.dart';
import '../../modules/dashboard/dashboard_page.dart';
import '../../modules/dashboard/dashboard_binding.dart';
import '../../modules/settings/settings_page.dart';
import '../../modules/settings/settings_binding.dart';
import '../../modules/authentication/auth_wrapper_page.dart';
import '../../modules/authentication/auth_binding.dart';
import '../../modules/authentication/login_page.dart';
import '../../modules/authentication/register_page.dart';
import '../../modules/authentication/forgot_password_page.dart';
import '../../modules/authentication/email_verification_page.dart';
import '../../modules/authentication/complete_profile_page.dart';
import '../../modules/authentication/account_loading_page.dart';
import '../../modules/provider_manager/provider_manager_page.dart';
import '../../modules/provider_manager/provider_manager_binding.dart';
import '../../modules/provider_manager/provider_form_page.dart';
import '../../modules/provider_manager/provider_details_page.dart';
import '../../modules/profiles/profile_page.dart';
import '../../modules/profiles/profile_binding.dart';
import '../../modules/about/about_page.dart';
import '../../modules/legal/privacy_policy_page.dart';
import '../../modules/legal/terms_of_service_page.dart';
import '../../modules/legal/licenses_page.dart';
import '../../modules/storage/storage_page.dart';
import '../../modules/live_tv/pages/home_page.dart';
import '../../modules/live_tv/pages/live_tv_page.dart';
import '../../modules/live_tv/pages/categories_page.dart';
import '../../modules/live_tv/pages/channel_details_page.dart';
import '../../modules/live_tv/pages/favorites_page.dart';
import '../../modules/live_tv/pages/recent_page.dart';
import '../../modules/live_tv/pages/search_page.dart';
import '../../modules/live_tv/pages/provider_overview_page.dart';
import '../../modules/live_tv/pages/library_overview_page.dart';
import '../../modules/live_tv/bindings/live_tv_binding.dart';
import '../../shared/widgets/empty_view.dart';

class AppPages {
  static const initial = AppRoutes.splash;

  static final unknownRoute = GetPage(
    name: AppRoutes.unknown,
    page: () => const Scaffold(
      body: EmptyView(
        title: 'Page Not Found',
        description:
            'The screen you are trying to access does not exist or has been moved.',
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
      name: AppRoutes.auth,
      page: () => const AuthWrapperPage(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: AppRoutes.authWrapper,
      page: () => const AuthWrapperPage(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: AppRoutes.login,
      page: () => const LoginPage(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: AppRoutes.register,
      page: () => const RegisterPage(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: AppRoutes.forgotPassword,
      page: () => const ForgotPasswordPage(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: AppRoutes.emailVerification,
      page: () => const EmailVerificationPage(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: AppRoutes.completeProfile,
      page: () => const CompleteProfilePage(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: AppRoutes.accountLoading,
      page: () => const AccountLoadingPage(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: AppRoutes.dashboard,
      page: () => const DashboardPage(),
      binding: DashboardBinding(),
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
    GetPage(
      name: AppRoutes.providerForm,
      page: () => ProviderFormPage(),
      binding: ProviderManagerBinding(),
    ),
    GetPage(
      name: AppRoutes.providerDetails,
      page: () => const ProviderDetailsPage(providerId: ''),
      binding: ProviderManagerBinding(),
    ),
    GetPage(
      name: AppRoutes.profile,
      page: () => const ProfilePage(),
      binding: ProfileBinding(),
    ),
    GetPage(
      name: AppRoutes.about,
      page: () => const AboutPage(),
      binding: SettingsBinding(),
    ),
    GetPage(
      name: AppRoutes.privacyPolicy,
      page: () => const PrivacyPolicyPage(),
      binding: SettingsBinding(),
    ),
    GetPage(
      name: AppRoutes.termsOfService,
      page: () => const TermsOfServicePage(),
      binding: SettingsBinding(),
    ),
    GetPage(
      name: AppRoutes.licenses,
      page: () => const LicensesPage(),
      binding: SettingsBinding(),
    ),
    GetPage(
      name: AppRoutes.storage,
      page: () => const StoragePage(),
      binding: SettingsBinding(),
    ),
    GetPage(
      name: AppRoutes.home,
      page: () => const HomePage(),
      binding: LiveTVBinding(),
    ),
    GetPage(
      name: AppRoutes.liveTV,
      page: () => const LiveTVPage(),
      binding: LiveTVBinding(),
    ),
    GetPage(
      name: AppRoutes.categories,
      page: () => const CategoriesPage(),
      binding: LiveTVBinding(),
    ),
    GetPage(
      name: AppRoutes.channelDetails,
      page: () => const ChannelDetailsPage(),
      binding: LiveTVBinding(),
    ),
    GetPage(
      name: AppRoutes.favorites,
      page: () => const FavoritesPage(),
      binding: LiveTVBinding(),
    ),
    GetPage(
      name: AppRoutes.recent,
      page: () => const RecentPage(),
      binding: LiveTVBinding(),
    ),
    GetPage(
      name: AppRoutes.search,
      page: () => const SearchPage(),
      binding: LiveTVBinding(),
    ),
    GetPage(
      name: AppRoutes.providerOverview,
      page: () => const ProviderOverviewPage(),
      binding: LiveTVBinding(),
    ),
    GetPage(
      name: AppRoutes.libraryOverview,
      page: () => const LibraryOverviewPage(),
      binding: LiveTVBinding(),
    ),
  ];
}
