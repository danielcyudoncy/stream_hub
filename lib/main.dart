import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:media_kit/media_kit.dart';
import 'core/bindings/app_binding.dart';
import 'core/constants/app_constants.dart';
import 'core/localization/app_translations.dart';
import 'core/logging/logging_service.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_pages.dart';
import 'data/models/settings_model.dart';
import 'data/models/cache_info.dart';
import 'modules/provider_manager/models/provider_model.dart';
import 'modules/profiles/models/profile_model.dart';
import 'data/services/database_service.dart';
import 'data/services/firebase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(ProviderModelAdapter());
  Hive.registerAdapter(ProfileModelAdapter());
  Hive.registerAdapter(CacheInfoAdapter());
  Hive.registerAdapter(SettingsModelAdapter());
  Get.put<LoggingService>(LoggingService(), permanent: true);
  final databaseService = DatabaseService();
  await databaseService.init();
  Get.put<DatabaseService>(databaseService, permanent: true);
  final firebaseService = FirebaseService();
  await firebaseService.init();
  Get.put<FirebaseService>(firebaseService, permanent: true);
  runApp(const StreamHubApp());
}

class StreamHubApp extends StatelessWidget {
  const StreamHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      initialBinding: AppBinding(),
      initialRoute: AppConstants.splashRoute,
      getPages: AppPages.pages,
      navigatorObservers: [GetObserver()],
      translations: AppTranslations(),
      locale: const Locale('en', 'US'),
      fallbackLocale: const Locale('en', 'US'),
      supportedLocales: const [Locale('en', 'US')],
    );
  }
}
