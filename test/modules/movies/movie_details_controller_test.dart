import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/media/media_library.dart';
import 'package:stream_hub/core/media/repositories/playback_repository.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/playback_session_model.dart';
import 'package:stream_hub/data/repositories/catalog_repository.dart';
import 'package:stream_hub/data/repositories/favorite_repository.dart';
import 'package:stream_hub/modules/movies/movie_details_controller.dart';

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
  Future<MediaItem?> getItem(String id) async {
    final idx = _items.indexWhere((i) => i.id == id);
    return idx >= 0 ? _items[idx] : null;
  }

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

class _MockPlaybackRepository implements PlaybackRepository {
  final Map<String, PlaybackSessionModel> sessions = {};

  @override
  Future<Duration?> getWatchProgress(String itemId) async =>
      sessions[itemId]?.resumePosition;

  @override
  Future<PlaybackSessionModel?> getWatchSession(String itemId) async =>
      sessions[itemId];

  @override
  Future<List<PlaybackSessionModel>> getAllWatchSessions() async =>
      sessions.values.toList();

  @override
  Future<void> saveWatchProgress(
    MediaItem item,
    Duration position,
    Duration duration,
  ) async {
    final comp = duration > Duration.zero
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;
    sessions[item.id] = PlaybackSessionModel(
      id: 'sess-${item.id}',
      itemId: item.id,
      providerType: item.providerType.displayName,
      resumePosition: position,
      completionPercentage: comp,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> deleteWatchProgress(String itemId) async {
    sessions.remove(itemId);
  }

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
  late _MockPlaybackRepository playbackRepo;
  late _MockMediaLibrary mediaLibrary;

  final testMovie = MediaItem(
    id: 'movie-1',
    providerId: 'prov-1',
    providerType: MediaSourceType.xtream,
    mediaType: MediaType.movie,
    title: 'The Dark Knight',
    genres: ['Action', 'Crime', 'Drama'],
    rating: 9.0,
    metadata: {
      'director': 'Christopher Nolan',
      'category_name': 'Action Movies',
      'cast': 'Christian Bale, Heath Ledger as Joker',
      'duration': '152',
    },
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final relatedMovie1 = MediaItem(
    id: 'movie-2',
    providerId: 'prov-1',
    providerType: MediaSourceType.xtream,
    mediaType: MediaType.movie,
    title: 'Batman Begins',
    genres: ['Action', 'Crime'],
    rating: 8.2,
    metadata: {
      'director': 'Christopher Nolan',
      'category_name': 'Action Movies',
    },
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final relatedMovie2 = MediaItem(
    id: 'movie-3',
    providerId: 'prov-1',
    providerType: MediaSourceType.xtream,
    mediaType: MediaType.movie,
    title: 'Inception',
    genres: ['Sci-Fi', 'Action'],
    rating: 8.8,
    metadata: {
      'director': 'Christopher Nolan',
    },
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final unrelatedMovie = MediaItem(
    id: 'movie-4',
    providerId: 'prov-1',
    providerType: MediaSourceType.xtream,
    mediaType: MediaType.movie,
    title: 'La La Land',
    genres: ['Romance', 'Comedy'],
    rating: 8.0,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  setUp(() {
    catalogRepo = _MockCatalogRepository([
      testMovie,
      relatedMovie1,
      relatedMovie2,
      unrelatedMovie,
    ]);
    favoriteRepo = _MockFavoriteRepository();
    playbackRepo = _MockPlaybackRepository();
    mediaLibrary = _MockMediaLibrary();
  });

  tearDown(() {
    Get.reset();
  });

  test('initializes movie details and extracts cast members', () async {
    Get.testMode = true;
    Get.parameters = {};

    final controller = MovieDetailsController(
      catalogRepository: catalogRepo,
      favoriteRepository: favoriteRepo,
      playbackRepository: playbackRepo,
      mediaLibrary: mediaLibrary,
    );

    // Pass movie in arguments
    Get.routing.args = testMovie;

    controller.onInit();
    await Future.delayed(const Duration(milliseconds: 50));

    expect(controller.movie, isNotNull);
    expect(controller.movie!.title, 'The Dark Knight');
    expect(controller.cast.length, 2);
    expect(controller.cast[0].name, 'Christian Bale');
    expect(controller.cast[1].name, 'Heath Ledger');
    expect(controller.cast[1].character, 'Joker');
  });

  test('calculates playAction as Play for unwatched movie', () async {
    Get.testMode = true;
    Get.routing.args = testMovie;

    final controller = MovieDetailsController(
      catalogRepository: catalogRepo,
      favoriteRepository: favoriteRepo,
      playbackRepository: playbackRepo,
      mediaLibrary: mediaLibrary,
    );

    controller.onInit();
    await Future.delayed(const Duration(milliseconds: 50));

    expect(controller.playAction.value, MoviePlayAction.play);
    expect(controller.actionButtonLabel, 'Play');
  });

  test('calculates playAction as Resume for partially watched movie', () async {
    Get.testMode = true;
    Get.routing.args = testMovie;

    // Save 30 min progress out of 152 min
    await playbackRepo.saveWatchProgress(
      testMovie,
      const Duration(minutes: 30),
      const Duration(minutes: 152),
    );

    final controller = MovieDetailsController(
      catalogRepository: catalogRepo,
      favoriteRepository: favoriteRepo,
      playbackRepository: playbackRepo,
      mediaLibrary: mediaLibrary,
    );

    controller.onInit();
    await Future.delayed(const Duration(milliseconds: 50));

    expect(controller.playAction.value, MoviePlayAction.resume);
    expect(controller.actionButtonLabel, 'Resume');
    expect(controller.watchProgress, isNotNull);
    expect(controller.watchProgress!.inMinutes, 30);
  });

  test('calculates playAction as Watch Again for finished movie', () async {
    Get.testMode = true;
    Get.routing.args = testMovie;

    // Save 96% progress
    await playbackRepo.saveWatchProgress(
      testMovie,
      const Duration(minutes: 148),
      const Duration(minutes: 152),
    );

    final controller = MovieDetailsController(
      catalogRepository: catalogRepo,
      favoriteRepository: favoriteRepo,
      playbackRepository: playbackRepo,
      mediaLibrary: mediaLibrary,
    );

    controller.onInit();
    await Future.delayed(const Duration(milliseconds: 50));

    expect(controller.playAction.value, MoviePlayAction.watchAgain);
    expect(controller.actionButtonLabel, 'Watch Again');
  });

  test('toggles favorite state on and off', () async {
    Get.testMode = true;
    Get.routing.args = testMovie;

    final controller = MovieDetailsController(
      catalogRepository: catalogRepo,
      favoriteRepository: favoriteRepo,
      playbackRepository: playbackRepo,
      mediaLibrary: mediaLibrary,
    );

    controller.onInit();
    await Future.delayed(const Duration(milliseconds: 50));

    expect(controller.isFavorite.value, isFalse);

    await controller.toggleFavorite();
    expect(controller.isFavorite.value, isTrue);

    await controller.toggleFavorite();
    expect(controller.isFavorite.value, isFalse);
  });

  test('scores and ranks related movies by genre and director', () async {
    Get.testMode = true;
    Get.routing.args = testMovie;

    final controller = MovieDetailsController(
      catalogRepository: catalogRepo,
      favoriteRepository: favoriteRepo,
      playbackRepository: playbackRepo,
      mediaLibrary: mediaLibrary,
    );

    controller.onInit();
    await Future.delayed(const Duration(milliseconds: 50));

    expect(controller.relatedMovies.isNotEmpty, isTrue);
    // Batman Begins should be first because it matches Director, Category, and 2 Genres
    expect(controller.relatedMovies.first.title, 'Batman Begins');
    // Inception should be second (same director and Action genre)
    expect(controller.relatedMovies[1].title, 'Inception');
  });
}
