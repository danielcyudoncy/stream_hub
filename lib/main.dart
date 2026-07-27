import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'core/bindings/initial_binding.dart';
import 'core/routes/app_pages.dart';
import 'core/services/app_initializer.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  // Run the full bootstrap before the widget tree is rendered.
  await AppInitializer.initialize();

  runApp(const StreamHubApp());
}

class StreamHubApp extends StatelessWidget {
  const StreamHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      // ─── App Identity ──────────────────────────────────────────────────
      title: 'StreamHub Pro',
      debugShowCheckedModeBanner: false,

      // ─── Themes ────────────────────────────────────────────────────────
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark, // Defaults to dark; SettingsController can change this at runtime.

      // ─── Routing ───────────────────────────────────────────────────────
      initialRoute: AppPages.initial,
      getPages: AppPages.pages,
      unknownRoute: AppPages.unknownRoute,

      // ─── Global Dependency Injection ───────────────────────────────────
      initialBinding: InitialBinding(),

      // ─── Default Page Transition ────────────────────────────────────────
      defaultTransition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
}
