import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/shared/widgets/hero_banner.dart';

void main() {
  group('HeroBanner Widget Tests', () {
    testWidgets('renders title, subtitle, metadata chips, and action buttons',
        (WidgetTester tester) async {
      bool playClicked = false;
      bool detailsClicked = false;
      bool favoriteClicked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HeroBanner(
              title: 'Inception',
              subtitle: 'A thief who steals corporate secrets through the use of dream-sharing technology.',
              imageUrl: '',
              rating: 8.8,
              year: '2010',
              genre: 'Sci-Fi • Action',
              quality: '4K',
              mediaType: 'Movie',
              isFavorite: true,
              onPlayPressed: () => playClicked = true,
              onDetailsPressed: () => detailsClicked = true,
              onFavoritePressed: () => favoriteClicked = true,
            ),
          ),
        ),
      );

      // Verify title & subtitle
      expect(find.text('Inception'), findsOneWidget);
      expect(
        find.textContaining('A thief who steals corporate secrets'),
        findsOneWidget,
      );

      // Verify metadata chips
      expect(find.text('MOVIE'), findsOneWidget);
      expect(find.text('8.8'), findsOneWidget);
      expect(find.text('2010'), findsOneWidget);
      expect(find.text('Sci-Fi • Action'), findsOneWidget);
      expect(find.text('4K'), findsOneWidget);

      // Verify action buttons
      expect(find.text('WATCH NOW'), findsOneWidget);
      expect(find.text('Details'), findsOneWidget);

      // Tap Watch Now
      await tester.tap(find.text('WATCH NOW'));
      await tester.pump();
      expect(playClicked, isTrue);

      // Tap Details
      await tester.tap(find.text('Details'));
      await tester.pump();
      expect(detailsClicked, isTrue);

      // Tap Favorite Bookmark
      await tester.tap(find.byIcon(Icons.bookmark_added_rounded));
      await tester.pump();
      expect(favoriteClicked, isTrue);
    });
  });
}
