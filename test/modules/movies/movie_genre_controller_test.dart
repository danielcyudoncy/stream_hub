import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/media/media_library.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/repositories/catalog_repository.dart';
import 'package:stream_hub/data/repositories/favorite_repository.dart';
import 'package:stream_hub/modules/movies/movie_genre_controller.dart';

class _MockCatalogRepository implements CatalogRepository {
  final List<MediaItem> _items = [];

  _MockCatalogRepository(List<MediaItem> initial) {
    _items.addAll(initial);
  }

  @override
  Future<List<MediaItem>> getAllItems() async => List.of(_items);

  @override
  Future<List<MediaItem>> getByType(MediaType type) async =>
      _items.where((i) => i.mediaType == type).toList();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockFavoriteRepository implements FavoriteRepository {
  final Set<String> _favIds = {};

  _MockFavoriteRepository({Set<String>? initial}) {
    if (initial != null) _favIds.addAll(initial);
  }

  @override
  Future<bool> isFavorite(String id) async => _favIds.contains(id);

  @override
  Future<void> add(MediaItem item) async => _favIds.add(item.id);

  @override
  Future<void> remove(String id) async => _favIds.remove(id);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockMediaLibrary implements MediaLibrary {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockCatalogRepository catalogRepo;
  late _MockFavoriteRepository favoriteRepo;
  late _MockMediaLibrary mediaLibrary;

  final movie1 = MediaItem(
    id: 'm1',
    providerId: 'prov-1',
    providerType: MediaSourceType.xtream,
    mediaType: MediaType.movie,
    title: 'Interstellar',
    genres: ['Science Fiction', 'Adventure'],
    rating: 8.7,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime.now(),
    metadata: {'year': 2014, 'duration': '169'},
  );

  final movie2 = MediaItem(
    id: 'm2',
    providerId: 'prov-1',
    providerType: MediaSourceType.xtream,
    mediaType: MediaType.movie,
    title: 'The Matrix',
    genres: ['Sci-Fi', 'Action'],
    rating: 8.7,
    createdAt: DateTime(2026, 2, 1),
    updatedAt: DateTime.now(),
    metadata: {'year': 1999, 'duration': '136'},
  );

  final movie3 = MediaItem(
    id: 'm3',
    providerId: 'prov-1',
    providerType: MediaSourceType.xtream,
    mediaType: MediaType.movie,
    title: 'Arrival',
    genres: ['SciFi', 'Mystery'],
    rating: 7.9,
    createdAt: DateTime(2026, 3, 1),
    updatedAt: DateTime.now(),
    metadata: {'year': 2016, 'duration': '116'},
  );

  final movie4 = MediaItem(
    id: 'm4',
    providerId: 'prov-1',
    providerType: MediaSourceType.xtream,
    mediaType: MediaType.movie,
    title: 'The Notebook',
    genres: ['Romance', 'Drama'],
    rating: 7.8,
    createdAt: DateTime(2026, 4, 1),
    updatedAt: DateTime.now(),
    metadata: {'year': 2004, 'duration': '123'},
  );

  setUp(() {
    catalogRepo = _MockCatalogRepository([movie1, movie2, movie3, movie4]);
    favoriteRepo = _MockFavoriteRepository();
    mediaLibrary = _MockMediaLibrary();
  });

  tearDown(() {
    Get.reset();
  });

  test('normalizes genre and matches variations like Sci-Fi, SciFi, Science Fiction', () async {
    Get.testMode = true;
    Get.routing.args = {'title': 'Sci-Fi'};

    final controller = MovieGenreController(
      catalogRepository: catalogRepo,
      favoriteRepository: favoriteRepo,
      mediaLibrary: mediaLibrary,
    );

    controller.onInit();
    await Future.delayed(const Duration(milliseconds: 50));

    expect(controller.displayedMovies.length, 3);
    final titles = controller.displayedMovies.map((m) => m.title).toList();
    expect(titles.contains('Interstellar'), isTrue);
    expect(titles.contains('The Matrix'), isTrue);
    expect(titles.contains('Arrival'), isTrue);
    expect(titles.contains('The Notebook'), isFalse);
  });

  test('filters movies by search query within genre', () async {
    Get.testMode = true;
    Get.routing.args = {'title': 'Sci-Fi'};

    final controller = MovieGenreController(
      catalogRepository: catalogRepo,
      favoriteRepository: favoriteRepo,
      mediaLibrary: mediaLibrary,
    );

    controller.onInit();
    await Future.delayed(const Duration(milliseconds: 50));

    expect(controller.displayedMovies.length, 3);

    controller.setSearchQuery('Matrix');
    expect(controller.displayedMovies.length, 1);
    expect(controller.displayedMovies.first.title, 'The Matrix');

    controller.setSearchQuery('');
    expect(controller.displayedMovies.length, 3);
  });

  test('sorts movies correctly by release year, rating, and title', () async {
    Get.testMode = true;
    Get.routing.args = {'title': 'Sci-Fi'};

    final controller = MovieGenreController(
      catalogRepository: catalogRepo,
      favoriteRepository: favoriteRepo,
      mediaLibrary: mediaLibrary,
    );

    controller.onInit();
    await Future.delayed(const Duration(milliseconds: 50));

    // Sort by release year descending
    controller.setSort(MovieGenreSortOption.year);
    expect(controller.displayedMovies[0].title, 'Arrival'); // 2016
    expect(controller.displayedMovies[1].title, 'Interstellar'); // 2014
    expect(controller.displayedMovies[2].title, 'The Matrix'); // 1999

    // Sort by Title A-Z
    controller.setSort(MovieGenreSortOption.titleAZ);
    expect(controller.displayedMovies[0].title, 'Arrival');
    expect(controller.displayedMovies[1].title, 'Interstellar');
    expect(controller.displayedMovies[2].title, 'The Matrix');
  });

  test('filters by favorites only', () async {
    Get.testMode = true;
    Get.routing.args = {'title': 'Sci-Fi'};

    favoriteRepo.add(movie2);

    final controller = MovieGenreController(
      catalogRepository: catalogRepo,
      favoriteRepository: favoriteRepo,
      mediaLibrary: mediaLibrary,
    );

    controller.onInit();
    await Future.delayed(const Duration(milliseconds: 50));

    expect(controller.displayedMovies.length, 3);

    controller.toggleFavoritesOnly();
    expect(controller.displayedMovies.length, 1);
    expect(controller.displayedMovies.first.title, 'The Matrix');
  });
}
