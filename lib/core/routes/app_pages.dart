import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'app_routes.dart';
import '../../modules/splash/splash_page.dart';
import '../../modules/splash/splash_binding.dart';
import '../../modules/home/home_page.dart';
import '../../modules/home/home_binding.dart';
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
import '../../modules/live_tv/pages/live_tv_page.dart';
import '../../modules/live_tv/pages/categories_page.dart';
import '../../modules/live_tv/pages/channel_details_page.dart';
import '../../modules/live_tv/pages/favorites_page.dart';
import '../../modules/live_tv/pages/recent_page.dart';
import '../../modules/live_tv/pages/provider_overview_page.dart';
import '../../modules/live_tv/pages/library_overview_page.dart';
import '../../modules/live_tv/bindings/live_tv_binding.dart';
import '../../modules/library/library_page.dart';
import '../../modules/library/library_binding.dart';
import '../../modules/search/search_hub_page.dart';
import '../../modules/search/search_hub_binding.dart';
import '../../modules/epg/pages/program_details_page.dart';
import '../../modules/epg/pages/channel_timeline_page.dart';
import '../../modules/epg/pages/guide_search_page.dart';
import '../../modules/epg/pages/mini_guide_page.dart';
import '../../modules/epg/bindings/epg_binding.dart';
import '../../modules/player/bindings/player_binding.dart';
import '../../modules/player/pages/fullscreen_player_page.dart';
import '../../modules/player/pages/embedded_player_page.dart';
import '../../modules/player/pages/mini_player_page.dart';
import '../../modules/developer/developer_page.dart';
import '../../modules/developer/developer_binding.dart';
import '../../modules/developer/pages/playback_test_page.dart';
import '../../modules/developer/pages/provider_test_page.dart';
import '../../modules/developer/pages/stream_test_page.dart';
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
      page: () => AuthWrapperPage(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: AppRoutes.authWrapper,
      page: () => AuthWrapperPage(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: AppRoutes.login,
      page: () => LoginPage(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: AppRoutes.register,
      page: () => RegisterPage(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: AppRoutes.forgotPassword,
      page: () => ForgotPasswordPage(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: AppRoutes.emailVerification,
      page: () => const EmailVerificationPage(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: AppRoutes.completeProfile,
      page: () => CompleteProfilePage(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: AppRoutes.accountLoading,
      page: () => const AccountLoadingPage(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: AppRoutes.home,
      page: () => const HomePage(),
      binding: HomeBinding(),
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
      name: AppRoutes.liveTV,
      page: () => const LiveTVPage(),
      binding: LiveTVBinding(),
    ),
    GetPage(
      name: AppRoutes.library,
      page: () => const LibraryPage(),
      binding: LibraryBinding(),
    ),
    GetPage(
      name: AppRoutes.search,
       page: () => SearchHubPage(),
      binding: SearchHubBinding(),
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
      name: AppRoutes.providerOverview,
      page: () => const ProviderOverviewPage(),
      binding: LiveTVBinding(),
    ),
    GetPage(
      name: AppRoutes.libraryOverview,
      page: () => const LibraryOverviewPage(),
      binding: LiveTVBinding(),
    ),
    GetPage(
      name: AppRoutes.guideSearch,
      page: () => const GuideSearchPage(),
      binding: EPGBinding(),
    ),
    GetPage(
      name: AppRoutes.miniGuide,
      page: () => const MiniGuidePage(),
      binding: EPGBinding(),
    ),
    GetPage(
      name: AppRoutes.programDetails,
      page: () => const ProgramDetailsPage(),
      binding: EPGBinding(),
    ),
    GetPage(
      name: AppRoutes.channelTimeline,
      page: () => const ChannelTimelinePage(),
      binding: EPGBinding(),
    ),
    GetPage(
      name: AppRoutes.fullscreenPlayer,
      page: () => const FullscreenPlayerPage(),
      binding: PlayerBinding(),
    ),
    GetPage(
      name: AppRoutes.embeddedPlayer,
      page: () => const EmbeddedPlayerPage(),
      binding: PlayerBinding(),
    ),
    GetPage(
      name: AppRoutes.miniPlayer,
      page: () => const MiniPlayerPage(),
      binding: PlayerBinding(),
    ),
    GetPage(
      name: AppRoutes.developer,
      page: () => const DeveloperPage(),
      binding: DeveloperBinding(),
    ),
    GetPage(
      name: AppRoutes.playbackTest,
      page: () => const PlaybackTestPage(),
      binding: DeveloperBinding(),
    ),
    GetPage(
      name: AppRoutes.providerTest,
      page: () => const ProviderTestPage(),
      binding: DeveloperBinding(),
    ),
    GetPage(
      name: AppRoutes.streamTest,
      page: () => const StreamTestPage(),
      binding: DeveloperBinding(),
    ),
  ];
}
