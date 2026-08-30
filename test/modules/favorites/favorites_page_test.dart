import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/media_catalog.dart';
import 'package:stream_hub/core/media/media_engine.dart';
import 'package:stream_hub/core/media/media_library.dart';
import 'package:stream_hub/core/media/media_source_manager.dart';
import 'package:stream_hub/core/theme/app_icons.dart';
import 'package:stream_hub/data/repositories/catalog_repository_impl.dart';
import 'package:stream_hub/modules/live_tv/controllers/favorites_controller.dart';
import 'package:stream_hub/modules/live_tv/pages/favorites_page.dart';
import 'package:stream_hub/shared/widgets/app_app_bar.dart';
import 'package:stream_hub/shared/widgets/app_scaffold.dart';

class _FakeMediaEngine implements MediaEngine {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeMediaLibrary implements MediaLibrary {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  setUp(() {
    Get.reset();
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('AppScaffold and AppAppBar render back button when showBackButton is true', (tester) async {
    bool backPressed = false;

    await tester.pumpWidget(
      GetMaterialApp(
        home: AppScaffold(
          title: 'Favorites',
          showBackButton: true,
          onBack: () {
            backPressed = true;
          },
          body: const SizedBox(),
        ),
      ),
    );

    expect(find.descendant(of: find.byType(AppAppBar), matching: find.text('Favorites')), findsOneWidget);
    expect(find.descendant(of: find.byType(AppAppBar), matching: find.byIcon(AppIcons.back)), findsOneWidget);

    await tester.tap(find.descendant(of: find.byType(AppAppBar), matching: find.byIcon(AppIcons.back)));
    await tester.pumpAndSettle();

    expect(backPressed, isTrue);
  });

  testWidgets('FavoritesPage contains back button in full page render', (tester) async {
    final catalog = MediaCatalog();
    final sourceManager = MediaSourceManager();
    final logger = LoggingService();
    final catalogRepo = CatalogRepositoryImpl(catalog, sourceManager, logger);
    final mediaEngine = _FakeMediaEngine();
    final mediaLibrary = _FakeMediaLibrary();

    final controller = FavoritesController(
      mediaEngine: mediaEngine,
      mediaLibrary: mediaLibrary,
      catalogRepository: catalogRepo,
    );
    Get.put<FavoritesController>(controller);

    await tester.pumpWidget(
      const GetMaterialApp(
        home: FavoritesPage(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.descendant(of: find.byType(AppAppBar), matching: find.text('Favorites')), findsOneWidget);
    expect(find.descendant(of: find.byType(AppAppBar), matching: find.byIcon(AppIcons.back)), findsOneWidget);
  });
}
