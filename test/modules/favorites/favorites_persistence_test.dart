import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/logging/logging_service.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/media/media_catalog.dart';
import 'package:stream_hub/core/media/media_engine.dart';
import 'package:stream_hub/core/media/media_library.dart';
import 'package:stream_hub/core/media/media_source_manager.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/repositories/catalog_repository_impl.dart';
import 'package:stream_hub/data/repositories/favorite_repository_impl.dart';
import 'package:stream_hub/data/services/favorite_service.dart';
import 'package:stream_hub/modules/live_tv/controllers/favorites_controller.dart';
import 'package:stream_hub/modules/live_tv/controllers/live_tv_controller.dart';
import 'package:hive/hive.dart';

class _FakeBox implements Box {
  final Map<dynamic, dynamic> _storage = {};

  @override
  Iterable get keys => _storage.keys;

  @override
  Iterable get values => _storage.values;

  @override
  dynamic get(key, {defaultValue}) => _storage.containsKey(key) ? _storage[key] : defaultValue;

  @override
  dynamic getAt(int index) => _storage.values.elementAt(index);

  @override
  Future<void> put(key, value) async => _storage[key] = value;

  @override
  Future<void> putAt(int index, value) async {
    final key = _storage.keys.elementAt(index);
    _storage[key] = value;
  }

  @override
  Future<void> putAll(Map<dynamic, dynamic> entries) async => _storage.addAll(entries);

  @override
  Future<void> delete(key) async => _storage.remove(key);

  @override
  Future<void> deleteAt(int index) async {
    final key = _storage.keys.elementAt(index);
    _storage.remove(key);
  }

  @override
  Future<void> deleteAll(Iterable keys) async {
    for (final k in keys) {
      _storage.remove(k);
    }
  }

  @override
  Future<int> clear() async {
    final count = _storage.length;
    _storage.clear();
    return count;
  }

  @override
  bool containsKey(key) => _storage.containsKey(key);

  @override
  bool get isEmpty => _storage.isEmpty;

  @override
  bool get isNotEmpty => _storage.isNotEmpty;

  @override
  bool get isOpen => true;

  @override
  int get length => _storage.length;

  @override
  String get name => 'favorites';

  @override
  String? get path => null;

  @override
  Future<void> close() async {}

  @override
  Future<void> compact() async {}

  @override
  Future<void> deleteFromDisk() async => _storage.clear();

  @override
  Future<void> flush() async {}

  @override
  dynamic keyAt(int index) => _storage.keys.elementAt(index);

  @override
  bool get lazy => false;

  @override
  Map<dynamic, dynamic> toMap() => Map.unmodifiable(_storage);

  @override
  Stream<BoxEvent> watch({key}) => const Stream.empty();

  @override
  Iterable valuesBetween({startKey, endKey}) => _storage.values;

  @override
  Future<int> add(value) async {
    final int key = _storage.length;
    _storage[key] = value;
    return key;
  }

  @override
  Future<Iterable<int>> addAll(Iterable values) async {
    final List<int> keys = [];
    for (final val in values) {
      final key = _storage.length;
      _storage[key] = val;
      keys.add(key);
    }
    return keys;
  }
}

class _FakeMediaEngine implements MediaEngine {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeMediaLibrary implements MediaLibrary {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late _FakeBox fakeBox;
  late LoggingService logger;
  late MediaCatalog catalog;
  late MediaSourceManager sourceManager;
  late CatalogRepositoryImpl catalogRepo;

  final testChannel1 = MediaItem(
    id: 'ch-1',
    providerId: 'prov-1',
    providerType: MediaSourceType.m3u,
    mediaType: MediaType.channel,
    title: 'Bein Sport 01',
    genres: const ['Sports'],
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final testChannel2 = MediaItem(
    id: 'ch-2',
    providerId: 'prov-1',
    providerType: MediaSourceType.m3u,
    mediaType: MediaType.channel,
    title: 'Bein Sport 02',
    genres: const ['Sports'],
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  setUp(() async {
    fakeBox = _FakeBox();
    logger = LoggingService();
    catalog = MediaCatalog();
    sourceManager = MediaSourceManager();
    catalogRepo = CatalogRepositoryImpl(catalog, sourceManager, logger);

    await catalogRepo.upsertItems([testChannel1, testChannel2]);
  });

  test('FavoriteService persists favorites into Hive and reloads on startup', () async {
    final serviceInstance1 = FavoriteService(logger: logger, box: fakeBox);
    await serviceInstance1.addFavorite(testChannel1);

    expect(serviceInstance1.isFavorite('ch-1'), isTrue);
    expect(serviceInstance1.isFavorite('ch-2'), isFalse);
    expect(fakeBox.containsKey('ch-1'), isTrue);

    // Simulate app restart by creating a new instance connected to the same box
    final serviceInstance2 = FavoriteService(logger: logger, box: fakeBox);
    expect(serviceInstance2.isFavorite('ch-1'), isTrue);
    expect(serviceInstance2.favoriteIds.contains('ch-1'), isTrue);
    expect(serviceInstance2.favoriteCount, equals(1));
  });

  test('FavoriteRepositoryImpl retrieves catalog items with favorite=true', () async {
    final service = FavoriteService(logger: logger, box: fakeBox);
    final repo = FavoriteRepositoryImpl(service, catalogRepo);

    await repo.add(testChannel1);

    final allFavs = await repo.getAll();
    expect(allFavs.length, equals(1));
    expect(allFavs.first.id, equals('ch-1'));
    expect(allFavs.first.title, equals('Bein Sport 01'));
    expect(allFavs.first.favorite, isTrue);
  });

  test('FavoritesController reacts to repo changes in real time', () async {
    final service = FavoriteService(logger: logger, box: fakeBox);
    final repo = FavoriteRepositoryImpl(service, catalogRepo);
    final mediaEngine = _FakeMediaEngine();
    final mediaLibrary = _FakeMediaLibrary();

    final favController = FavoritesController(
      mediaEngine: mediaEngine,
      mediaLibrary: mediaLibrary,
      catalogRepository: catalogRepo,
      favoriteRepository: repo,
    );

    favController.onInit();
    await Future.delayed(const Duration(milliseconds: 50));

    expect(favController.favoriteChannels.isEmpty, isTrue);

    // Add favorite via repo / another controller
    await repo.add(testChannel1);
    await Future.delayed(const Duration(milliseconds: 50));

    expect(favController.favoriteChannels.length, equals(1));
    expect(favController.favoriteChannels.first.title, equals('Bein Sport 01'));

    favController.onClose();
  });

  test('LiveTVController correctly maps favorites on load and toggles them', () async {
    final service = FavoriteService(logger: logger, box: fakeBox);
    final repo = FavoriteRepositoryImpl(service, catalogRepo);
    await repo.add(testChannel1);

    final mediaEngine = _FakeMediaEngine();
    final mediaLibrary = _FakeMediaLibrary();

    final liveTvController = LiveTVController(
      mediaEngine: mediaEngine,
      mediaLibrary: mediaLibrary,
      catalogRepository: catalogRepo,
      favoriteRepository: repo,
    );

    liveTvController.onInit();
    await Future.delayed(const Duration(milliseconds: 50));

    expect(liveTvController.favorites.length, equals(1));
    expect(liveTvController.favorites.first.id, equals('ch-1'));

    final ch1InList = liveTvController.channels.firstWhere((c) => c.id == 'ch-1');
    expect(ch1InList.favorite, isTrue);

    final ch2InList = liveTvController.channels.firstWhere((c) => c.id == 'ch-2');
    expect(ch2InList.favorite, isFalse);

    // Toggle ch-2 to favorite
    await liveTvController.toggleFavorite(ch2InList);
    await Future.delayed(const Duration(milliseconds: 50));

    expect(liveTvController.favorites.length, equals(2));
    expect(fakeBox.containsKey('ch-2'), isTrue);

    liveTvController.onClose();
  });
}
