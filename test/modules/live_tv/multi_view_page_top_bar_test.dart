import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/media/enums/stream_type.dart';
import 'package:stream_hub/core/media/media_engine.dart';
import 'package:stream_hub/core/media/media_library.dart';
import 'package:stream_hub/core/streaming/models/playable_session.dart';
import 'package:stream_hub/core/streaming/repositories/stream_repository.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/repositories/catalog_repository.dart';
import 'package:stream_hub/modules/live_tv/controllers/multi_view_controller.dart';
import 'package:stream_hub/modules/live_tv/models/multi_view_layout_mode.dart';
import 'package:stream_hub/modules/live_tv/pages/multi_view_page.dart';

class _FakeCatalogRepository extends Fake implements CatalogRepository {
  final List<MediaItem> items = [];

  @override
  Future<List<MediaItem>> getAllItems() async => List.of(items);

  @override
  Future<List<MediaItem>> getByType(MediaType type) async =>
      List.of(items.where((item) => item.mediaType == type));
}

class _FakeMediaLibrary extends Fake implements MediaLibrary {
  @override
  Stream<List<MediaItem>> get liveTVStream => const Stream<List<MediaItem>>.empty();

  @override
  List<MediaItem> getLiveTV() => [];
}

class _FakeMediaEngine extends Fake implements MediaEngine {}

class _FakeStreamRepository extends Fake implements StreamRepository {
  @override
  Future<PlayableSession> resolvePlayback({
    required String mediaItemId,
    required MediaSourceType providerType,
    required Map<String, dynamic> itemMetadata,
    String? providerId,
    String? fallbackUrl,
    bool useCache = true,
    bool validate = true,
  }) async {
    return PlayableSession(
      sessionId: 'session_$mediaItemId',
      mediaItemId: mediaItemId,
      providerId: providerId ?? 'provider',
      providerType: providerType,
      streamUrl: fallbackUrl ?? 'https://example.com/live/stream.m3u8',
      streamType: StreamType.hls,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeCatalogRepository catalogRepo;
  late MediaEngine mediaEngine;
  late MediaLibrary mediaLibrary;
  late MultiViewController controller;

  setUp(() {
    Get.testMode = true;
    catalogRepo = _FakeCatalogRepository();
    Get.put<StreamRepository>(_FakeStreamRepository());

    mediaEngine = _FakeMediaEngine();
    mediaLibrary = _FakeMediaLibrary();

    controller = MultiViewController(
      catalogRepository: catalogRepo,
      mediaEngine: mediaEngine,
      mediaLibrary: mediaLibrary,
    );
    Get.put<MultiViewController>(controller);
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('MultiViewPage displays top bar with title, layout badge, and Change Layout button', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1080));

    await tester.pumpWidget(
      GetMaterialApp(
        home: const MultiViewPage(),
      ),
    );
    await tester.pump();

    // Verify Title
    expect(find.text('Multi-View'), findsOneWidget);

    // Verify initial layout badge (Quad View by default)
    expect(find.text('4 Screens (Quad View)'), findsOneWidget);

    // Verify Change Layout and Exit buttons
    expect(find.text('Change Layout'), findsOneWidget);
    expect(find.text('Exit'), findsOneWidget);

    // Tap Change Layout
    await tester.tap(find.text('Change Layout'));
    await tester.pumpAndSettle();

    // Dialog opens
    expect(find.text('Choose Multi-View Layout'), findsOneWidget);

    // Select Triple View
    await tester.tap(find.text('Triple View'));
    await tester.pumpAndSettle();

    // Badge updates to Triple
    expect(find.text('3 Screens (1 Main + 2 Small)'), findsOneWidget);
    expect(controller.layoutMode.value, equals(MultiViewLayoutMode.triple));
  });

  testWidgets('Pressing remote Menu/ContextMenu key opens layout dialog', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1080));

    await tester.pumpWidget(
      GetMaterialApp(
        home: const MultiViewPage(),
      ),
    );
    await tester.pump();

    // Dialog is initially not present
    expect(find.text('Choose Multi-View Layout'), findsNothing);

    // Simulate pressing the remote Menu (contextMenu) key
    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await tester.pumpAndSettle();

    // Dialog opened via remote menu button!
    expect(find.text('Choose Multi-View Layout'), findsOneWidget);

    // Select Side-by-Side (2 Screens)
    await tester.tap(find.text('Dual (Side-by-Side)'));
    await tester.pumpAndSettle();

    expect(find.text('Choose Multi-View Layout'), findsNothing);
    expect(find.text('2 Screens (Side-by-Side)'), findsOneWidget);
    expect(controller.layoutMode.value, equals(MultiViewLayoutMode.dualHorizontal));
  });
}
