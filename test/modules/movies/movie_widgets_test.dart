import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/modules/movies/widgets/continue_watching_movie_card.dart';
import 'package:stream_hub/modules/movies/widgets/movie_card.dart';
import 'package:stream_hub/modules/movies/widgets/movie_carousel.dart';
import 'package:stream_hub/modules/movies/widgets/movie_grid.dart';
import 'package:stream_hub/modules/movies/widgets/movie_hero_banner.dart';

MediaItem _testMovie({
  required String id,
  required String title,
  double? rating,
  List<String> genres = const [],
  Map<String, dynamic> metadata = const {},
  bool favorite = false,
}) {
  return MediaItem(
    id: id,
    providerId: 'prov-1',
    providerType: MediaSourceType.xtream,
    mediaType: MediaType.movie,
    title: title,
    description: 'This is the description for $title.',
    rating: rating,
    genres: genres,
    metadata: metadata,
    favorite: favorite,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

void main() {
  group('MovieCard Widget Tests', () {
    testWidgets('renders title, rating badge, and release year',
        (tester) async {
      final movie = _testMovie(
        id: 'm1',
        title: 'Inception',
        rating: 8.8,
        genres: ['Sci-Fi', 'Action'],
        metadata: {'year': '2010', 'duration': '148 min'},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 150,
                height: 220,
                child: MovieCard(
                  item: movie,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Inception'), findsOneWidget);
      expect(find.text('8.8'), findsOneWidget);
      expect(find.textContaining('2010'), findsOneWidget);
    });

    testWidgets('triggers onTap and onToggleFavorite callbacks',
        (tester) async {
      bool tapped = false;
      bool favorited = false;
      final movie = _testMovie(
        id: 'm2',
        title: 'Interstellar',
        rating: 8.7,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 150,
                height: 220,
                child: MovieCard(
                  item: movie,
                  onTap: () => tapped = true,
                  onToggleFavorite: () => favorited = true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Interstellar'));
      await tester.pump();
      expect(tapped, isTrue);

      final favButton = find.byIcon(Icons.favorite_border_rounded);
      expect(favButton, findsOneWidget);
      await tester.tap(favButton);
      await tester.pump();
      expect(favorited, isTrue);
    });

    testWidgets(
        'renders progress bar when progressPercentage is between 0 and 1',
        (tester) async {
      final movie = _testMovie(
        id: 'm3',
        title: 'The Dark Knight',
        rating: 9.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 150,
                height: 220,
                child: MovieCard(
                  item: movie,
                  progressPercentage: 0.65,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });

  group('ContinueWatchingMovieCard Widget Tests', () {
    testWidgets('renders thumbnail, title, remaining time, and triggers resume',
        (tester) async {
      bool resumed = false;
      final movie = _testMovie(
        id: 'cw1',
        title: 'Dune: Part Two',
        metadata: {'duration': '166 min'},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 280,
                child: ContinueWatchingMovieCard(
                  item: movie,
                  position: const Duration(minutes: 60),
                  duration: const Duration(minutes: 166),
                  onResume: () => resumed = true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dune: Part Two'), findsOneWidget);
      expect(find.textContaining('remaining'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      await tester.tap(find.text('Dune: Part Two'));
      await tester.pump();
      expect(resumed, isTrue);
    });
  });

  group('MovieHeroBanner Widget Tests', () {
    testWidgets('renders hero details, genres, and action buttons',
        (tester) async {
      bool watched = false;
      bool detailsTapped = false;
      bool favoriteToggled = false;

      final movie = _testMovie(
        id: 'hero-1',
        title: 'Oppenheimer',
        rating: 8.9,
        genres: ['Biography', 'Drama', 'History'],
        metadata: {
          'year': '2023',
          'runtime': 180,
          'director': 'Christopher Nolan',
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MovieHeroBanner(
                movie: movie,
                resumePosition: const Duration(minutes: 45),
                onWatch: () => watched = true,
                onDetails: () => detailsTapped = true,
                onToggleFavorite: () => favoriteToggled = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Oppenheimer'), findsOneWidget);
      expect(find.text('8.9'), findsOneWidget);
      expect(find.text('2023'), findsOneWidget);
      expect(find.text('3h'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);
      expect(find.text('Details'), findsOneWidget);

      await tester.tap(find.text('Resume'));
      await tester.pump();
      expect(watched, isTrue);

      await tester.tap(find.text('Details'));
      await tester.pump();
      expect(detailsTapped, isTrue);

      await tester.tap(find.text('My List'));
      await tester.pump();
      expect(favoriteToggled, isTrue);
    });
  });

  group('MovieCarousel Widget Tests', () {
    testWidgets('renders section title, subtitle, See All button, and cards',
        (tester) async {
      bool seeAllTapped = false;
      MediaItem? selectedMovie;

      final movies = [
        _testMovie(id: 'c1', title: 'Action Movie 1'),
        _testMovie(id: 'c2', title: 'Action Movie 2'),
        _testMovie(id: 'c3', title: 'Action Movie 3'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MovieCarousel(
              title: 'Action & Adventure',
              subtitle: 'High octane thrillers',
              movies: movies,
              onSeeAll: () => seeAllTapped = true,
              onMovieTap: (m) => selectedMovie = m,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Action & Adventure'), findsOneWidget);
      expect(find.text('High octane thrillers'), findsOneWidget);
      expect(find.text('See All'), findsOneWidget);
      expect(find.text('Action Movie 1'), findsOneWidget);

      await tester.tap(find.text('See All'));
      await tester.pump();
      expect(seeAllTapped, isTrue);

      await tester.tap(find.text('Action Movie 1'));
      await tester.pump();
      expect(selectedMovie?.id, 'c1');
    });
  });

  group('MovieGrid Widget Tests', () {
    testWidgets('renders responsive grid of movies and handles taps',
        (tester) async {
      MediaItem? tappedMovie;
      final movies = [
        _testMovie(id: 'g1', title: 'Grid Movie 1'),
        _testMovie(id: 'g2', title: 'Grid Movie 2'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MovieGrid(
              movies: movies,
              onMovieTap: (m) => tappedMovie = m,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Grid Movie 1'), findsOneWidget);
      expect(find.text('Grid Movie 2'), findsOneWidget);

      await tester.tap(find.text('Grid Movie 1'));
      await tester.pump();
      expect(tappedMovie?.id, 'g1');
    });
  });
}
