import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/modules/home/widgets/home_content_rail.dart';
import 'package:stream_hub/modules/home/widgets/home_continue_watching_card.dart';
import 'package:stream_hub/shared/widgets/cached_home_image.dart';

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
  });

  final sampleItem = MediaItem(
    id: 'cw-1',
    providerId: 'prov-1',
    providerType: MediaSourceType.xtream,
    mediaType: MediaType.movie,
    title: 'Inception',
    backdrop: 'https://image.tmdb.org/t/p/w500/backdrop.jpg',
    poster: 'https://image.tmdb.org/t/p/w500/poster.jpg',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    metadata: {
      'watchProgress': 0.65,
      'duration': 7200,
      'position': 4680,
    },
  );

  testWidgets('HomeContentRail applies vertical headroom and Clip.none for focus expansion', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: HomeContentRail(
            title: 'Continue Watching',
            items: [sampleItem],
            cardWidth: 220.0,
            cardHeight: 155.0,
            itemBuilder: (context, item, index) {
              return HomeContinueWatchingCard(
                item: item,
                onTap: () {},
              );
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify ListView exists with Clip.none
    final listViewFinder = find.byType(ListView);
    expect(listViewFinder, findsOneWidget);
    final listView = tester.widget<ListView>(listViewFinder);
    expect(listView.clipBehavior, equals(Clip.none));

    // Verify rail height exceeds effective card height to provide vertical focus headroom
    final sizedBoxFinders = find.byType(SizedBox);
    bool foundRailContainer = false;
    for (final element in sizedBoxFinders.evaluate()) {
      final widget = element.widget as SizedBox;
      if (widget.height != null && widget.height! > 155.0) {
        foundRailContainer = true;
        break;
      }
    }
    expect(foundRailContainer, isTrue, reason: 'Rail container should have vertical headroom > 155.0');
  });

  testWidgets('HomeContinueWatchingCard renders landscape artwork with BoxFit.cover', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 220.0,
            height: 155.0,
            child: HomeContinueWatchingCard(
              item: sampleItem,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    // Verify item title is rendered
    expect(find.text('Inception'), findsOneWidget);

    // Verify CachedHomeImage is configured with BoxFit.cover
    final cachedImageFinder = find.byType(CachedHomeImage);
    expect(cachedImageFinder, findsOneWidget);
    final cachedImage = tester.widget<CachedHomeImage>(cachedImageFinder);
    expect(cachedImage.fit, equals(BoxFit.cover));
    // Verify backdrop is preferred over poster for landscape continue watching
    expect(cachedImage.imageUrl, contains('backdrop.jpg'));
  });
}
