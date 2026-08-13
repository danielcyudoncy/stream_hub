# Movies Screen UI Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refresh the movies screen with a 3-card featured carousel, curated movie rows, ratings on cards, a 3-column movie grid, and an unavailable message for non-playable movies.

**Architecture:** Keep the implementation inside the existing `movies` module, mirroring the proven sectioned layout already used by the `series` screen. Put curation and playability checks in `MoviesController`, keep UI assembly in `MoviesPage`, and reuse `MediaPosterCard`, `MediaCarousel`, and `MediaSection` wherever possible.

**Tech Stack:** Flutter, Dart, GetX, `flutter_test`

---

## File Map

- Modify: `lib/modules/movies/movies_controller.dart`
  - Add curated movie lists and metadata-first backfill helpers.
- Modify: `lib/modules/movies/movies_page.dart`
  - Replace the grid-first layout with a featured carousel, curated rows, and a 3-column bottom grid.
- Reuse: `lib/shared/widgets/media_poster_card.dart`
  - Keep ratings visible on cards. Do not change this file unless the final UI cannot achieve the featured layout cleanly without a small safe tweak.
- Reuse: `lib/shared/widgets/media_carousel.dart`
  - Use for the featured 3-card movie carousel.
- Reuse: `lib/shared/widgets/media_section.dart`
  - Use for the curated horizontal rows.
- Create: `test/modules/movies/movies_controller_test.dart`
  - Cover curation, backfill, and playability checks.

## Constraints

- Do not commit from this plan. The user requested to handle commits manually.
- Do not overwrite unrelated dirty changes in `series` or shared widget files.
- Keep the screen movie-only. Do not add any series-backed content to `MoviesPage`.
- Show `This movie is not available right now.` only when the tap cannot proceed because the item has no playable source.

### Task 1: Add Controller Tests First

**Files:**
- Create: `test/modules/movies/movies_controller_test.dart`
- Modify: `lib/modules/movies/movies_controller.dart`

- [ ] **Step 1: Write the failing controller test file**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/core/media/enums/media_source_type.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/media/media_engine.dart';
import 'package:stream_hub/core/media/media_library.dart';
import 'package:stream_hub/data/models/media_item.dart';
import 'package:stream_hub/data/models/media_sync_result.dart';
import 'package:stream_hub/data/models/xmltv_models.dart';
import 'package:stream_hub/data/repositories/catalog_repository.dart';
import 'package:stream_hub/modules/movies/movies_controller.dart';

class _FakeCatalogRepository implements CatalogRepository {
  final List<MediaItem> items = [];

  @override
  Future<List<MediaItem>> getAllItems() async => List.of(items);

  @override
  Future<void> upsertItems(List<MediaItem> newItems) async {}

  @override
  Future<MediaItem?> getItem(String id) async => null;

  @override
  Future<void> deleteItem(String id) async {}

  @override
  Future<void> clear() async {}

  @override
  Future<List<MediaSyncResult>> syncAll() => throw UnimplementedError();

  @override
  Future<MediaSyncResult> syncSource(String sourceId) =>
      throw UnimplementedError();

  @override
  Future<void> refresh() async {}

  @override
  Stream<List<MediaItem>> watchUpdates() => const Stream.empty();

  @override
  Future<void> enrichWithXMLTV(XMLTVGuide guide) async {}

  @override
  Future<void> mergeXMLTVMetadata(XMLTVGuide guide) async {}
}

class _FakeMediaEngine implements MediaEngine {}

class _FakeMediaLibrary implements MediaLibrary {}

MediaItem movie({
  required String id,
  required String title,
  List<String> genres = const [],
  double? rating,
  DateTime? createdAt,
  DateTime? updatedAt,
  Map<String, dynamic> metadata = const {},
}) {
  final now = DateTime(2026, 8, 13);
  return MediaItem(
    id: id,
    providerId: 'provider-1',
    providerType: MediaSourceType.xtream,
    mediaType: MediaType.movie,
    title: title,
    genres: genres,
    rating: rating,
    metadata: metadata,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
  );
}

void main() {
  late _FakeCatalogRepository catalogRepository;

  MoviesController buildController() {
    return MoviesController(
      mediaEngine: _FakeMediaEngine(),
      mediaLibrary: _FakeMediaLibrary(),
      catalogRepository: catalogRepository,
    );
  }

  Future<void> pumpLoad(MoviesController controller) async {
    controller.onInit();
    while (controller.isLoading.value) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
  }

  setUp(() {
    catalogRepository = _FakeCatalogRepository();
  });

  test('builds a 3-item featured carousel from rated movies first', () async {
    catalogRepository.items.addAll([
      movie(id: 'm1', title: 'One', rating: 7.1),
      movie(id: 'm2', title: 'Two', rating: 8.4),
      movie(id: 'm3', title: 'Three', rating: 9.2),
      movie(id: 'm4', title: 'Four', rating: 6.8),
    ]);

    final controller = buildController();
    await pumpLoad(controller);

    expect(controller.featuredMovies.length, 3);
    expect(controller.featuredMovies.map((item) => item.id), ['m3', 'm2', 'm1']);
  });

  test('backfills metadata rows when no direct genre matches exist', () async {
    catalogRepository.items.addAll([
      movie(id: 'm1', title: 'One', rating: 8.0),
      movie(id: 'm2', title: 'Two', rating: 7.5),
      movie(id: 'm3', title: 'Three', rating: 7.0),
      movie(id: 'm4', title: 'Four', rating: 6.5),
    ]);

    final controller = buildController();
    await pumpLoad(controller);

    expect(controller.mysteryThrillerMovies, isNotEmpty);
    expect(controller.romanticComedyMovies, isNotEmpty);
    expect(controller.topRatedMovies, isNotEmpty);
  });

  test('uses recent movies for new this week and backfills when needed', () async {
    final now = DateTime(2026, 8, 13);
    catalogRepository.items.addAll([
      movie(
        id: 'm1',
        title: 'Fresh',
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      movie(
        id: 'm2',
        title: 'Older One',
        createdAt: now.subtract(const Duration(days: 20)),
      ),
      movie(
        id: 'm3',
        title: 'Older Two',
        createdAt: now.subtract(const Duration(days: 30)),
      ),
    ]);

    final controller = buildController();
    await pumpLoad(controller);

    expect(controller.newThisWeekMovies, isNotEmpty);
    expect(controller.newThisWeekMovies.first.id, 'm1');
  });

  test('marks a movie playable when metadata contains a stream url', () {
    final controller = buildController();
    final item = movie(
      id: 'm1',
      title: 'Playable',
      metadata: {'streamUrl': 'http://example.com/movie.m3u8'},
    );

    expect(controller.canOpenMovie(item), isTrue);
  });

  test('marks a movie unavailable when stream metadata is missing', () {
    final controller = buildController();
    final item = movie(id: 'm1', title: 'Unavailable');

    expect(controller.canOpenMovie(item), isFalse);
  });
}
```

- [ ] **Step 2: Run the new controller tests to confirm they fail**

Run:

```bash
flutter test test/modules/movies/movies_controller_test.dart
```

Expected: FAIL with missing `featuredMovies`, `mysteryThrillerMovies`, `romanticComedyMovies`, `topRatedMovies`, `newThisWeekMovies`, or `canOpenMovie`.

- [ ] **Step 3: Add the controller API needed by the tests**

Add these members to `lib/modules/movies/movies_controller.dart`:

```dart
final RxList<MediaItem> featuredMovies = <MediaItem>[].obs;
final RxList<MediaItem> trendingMovies = <MediaItem>[].obs;
final RxList<MediaItem> newThisWeekMovies = <MediaItem>[].obs;
final RxList<MediaItem> mysteryThrillerMovies = <MediaItem>[].obs;
final RxList<MediaItem> romanticComedyMovies = <MediaItem>[].obs;
final RxList<MediaItem> topRatedMovies = <MediaItem>[].obs;

bool canOpenMovie(MediaItem item) {
  final streamUrl = item.metadata['streamUrl']?.toString();
  final directSource = item.metadata['directSource']?.toString();
  final streamId = item.metadata['streamId']?.toString();
  return (streamUrl != null && streamUrl.isNotEmpty) ||
      (directSource != null && directSource.isNotEmpty) ||
      (streamId != null && streamId.isNotEmpty);
}
```

- [ ] **Step 4: Run the tests again to verify the failure narrows to curation logic**

Run:

```bash
flutter test test/modules/movies/movies_controller_test.dart
```

Expected: FAIL in assertions for list ordering or missing backfill behavior, but no longer fail for missing symbols.

### Task 2: Implement Movie Curation In `MoviesController`

**Files:**
- Modify: `lib/modules/movies/movies_controller.dart`
- Test: `test/modules/movies/movies_controller_test.dart`

- [ ] **Step 1: Add section computation after loading movies**

Update `_loadMovies()` so it computes sections after assigning `movies`:

```dart
Future<void> _loadMovies() async {
  isLoading.value = true;
  try {
    final allItems = await catalogRepository.getAllItems();
    final movieItems = allItems
        .where((item) => item.mediaType == MediaType.movie)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    movies.assignAll(movieItems);
    _computeSections(movieItems);
  } catch (e) {
    // Log error
  } finally {
    isLoading.value = false;
  }
}
```

- [ ] **Step 2: Implement the section builder and metadata-first selection helpers**

Add these helpers to `lib/modules/movies/movies_controller.dart`:

```dart
void _computeSections(List<MediaItem> allMovies) {
  final now = DateTime.now();
  final weekAgo = now.subtract(const Duration(days: 7));

  featuredMovies.assignAll(
    _takePreferred(
      preferred: allMovies.where((item) => item.rating != null).toList()
        ..sort((a, b) {
          final ratingCompare = b.rating!.compareTo(a.rating!);
          if (ratingCompare != 0) return ratingCompare;
          return b.updatedAt.compareTo(a.updatedAt);
        }),
      fallback: allMovies,
      limit: 3,
    ),
  );

  trendingMovies.assignAll(
    _takePreferred(
      preferred: List<MediaItem>.of(allMovies),
      fallback: allMovies,
      limit: 15,
    ),
  );

  newThisWeekMovies.assignAll(
    _takePreferred(
      preferred: allMovies
          .where((item) => item.createdAt.isAfter(weekAgo))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      fallback: allMovies,
      limit: 15,
    ),
  );

  mysteryThrillerMovies.assignAll(
    _takePreferred(
      preferred: allMovies.where(_isMysteryOrThriller).toList(),
      fallback: allMovies,
      limit: 15,
    ),
  );

  romanticComedyMovies.assignAll(
    _takePreferred(
      preferred: _sortRomanticComedyMatches(allMovies),
      fallback: allMovies,
      limit: 15,
    ),
  );

  topRatedMovies.assignAll(
    _takePreferred(
      preferred: allMovies.where((item) => item.rating != null).toList()
        ..sort((a, b) => b.rating!.compareTo(a.rating!)),
      fallback: allMovies,
      limit: 15,
    ),
  );
}

List<MediaItem> _takePreferred({
  required List<MediaItem> preferred,
  required List<MediaItem> fallback,
  required int limit,
}) {
  final result = <MediaItem>[];
  final seen = <String>{};

  void addItems(Iterable<MediaItem> items) {
    for (final item in items) {
      if (result.length >= limit) return;
      if (seen.add(item.id)) {
        result.add(item);
      }
    }
  }

  addItems(preferred);
  addItems(fallback);
  return result.take(limit).toList();
}

bool _isMysteryOrThriller(MediaItem item) {
  final genres = item.genres.map((genre) => genre.toLowerCase()).toList();
  return genres.any((genre) => genre.contains('mystery')) ||
      genres.any((genre) => genre.contains('thriller'));
}

List<MediaItem> _sortRomanticComedyMatches(List<MediaItem> items) {
  final both = <MediaItem>[];
  final partial = <MediaItem>[];

  for (final item in items) {
    final genres = item.genres.map((genre) => genre.toLowerCase()).toList();
    final hasRomance = genres.any((genre) => genre.contains('romance'));
    final hasComedy = genres.any((genre) => genre.contains('comedy'));
    if (hasRomance && hasComedy) {
      both.add(item);
    } else if (hasRomance || hasComedy) {
      partial.add(item);
    }
  }

  return [...both, ...partial];
}
```

- [ ] **Step 3: Run the focused controller tests**

Run:

```bash
flutter test test/modules/movies/movies_controller_test.dart
```

Expected: PASS for all new `MoviesController` tests.

- [ ] **Step 4: Optional cleanup if ordering expectations fail due to shared timestamps**

If the featured ordering test is flaky because all fallback items share the same date, update only the test fixture dates, not the production logic:

```dart
movie(
  id: 'm2',
  title: 'Two',
  rating: 8.4,
  updatedAt: DateTime(2026, 8, 12),
),
```

- [ ] **Step 5: Run the focused controller tests again**

Run:

```bash
flutter test test/modules/movies/movies_controller_test.dart
```

Expected: PASS with stable ordering assertions.

### Task 3: Rebuild `MoviesPage` Around Carousel + Curated Rows

**Files:**
- Modify: `lib/modules/movies/movies_page.dart`
- Reuse: `lib/shared/widgets/media_carousel.dart`
- Reuse: `lib/shared/widgets/media_section.dart`
- Reuse: `lib/shared/widgets/media_poster_card.dart`

- [ ] **Step 1: Add the shared imports used by the sectioned layout**

Update the imports in `lib/modules/movies/movies_page.dart`:

```dart
import '../../../shared/widgets/media_carousel.dart';
import '../../../shared/widgets/media_section.dart';
```

- [ ] **Step 2: Replace the grid-first body with the sectioned screen layout**

Use this structure inside the success state:

```dart
return CustomScrollView(
  slivers: [
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Text(
          '${controller.movies.length} Movies',
          style: AppTypography.getCaption(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    ),
    if (controller.featuredMovies.isNotEmpty) ...[
      SliverToBoxAdapter(
        child: MediaCarousel(
          items: controller.featuredMovies,
          itemWidth: 120,
          itemBuilder: (context, item, index) {
            final mediaItem = item as MediaItem;
            return MediaPosterCard(
              item: mediaItem,
              onTap: () => _openItem(context, mediaItem),
            );
          },
        ),
      ),
      SliverToBoxAdapter(child: AppSpacing.heightSM),
    ],
    _buildSection(title: 'Trending Movies', items: controller.trendingMovies),
    _buildSection(title: 'New This Week', items: controller.newThisWeekMovies),
    _buildSection(
      title: 'Mystery & Thriller',
      items: controller.mysteryThrillerMovies,
    ),
    _buildSection(
      title: 'Romantic Comedies',
      items: controller.romanticComedyMovies,
    ),
    _buildSection(title: 'Top Rated', items: controller.topRatedMovies),
    SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
          childAspectRatio: 0.7,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = controller.movies[index];
            return MediaPosterCard(
              item: item,
              onTap: () => _openItem(context, item),
            );
          },
          childCount: controller.movies.length,
        ),
      ),
    ),
  ],
);
```

- [ ] **Step 3: Add a reusable private section builder to the page**

Add this helper below `build()`:

```dart
Widget _buildSection({
  required String title,
  required List<MediaItem> items,
}) {
  if (items.isEmpty) {
    return const SliverToBoxAdapter(child: SizedBox.shrink());
  }

  return SliverToBoxAdapter(
    child: MediaSection(
      title: title,
      items: items,
      onSeeAll: () {},
      itemBuilder: (context, item, index) {
        return MediaPosterCard(
          item: item,
          onTap: () => _openItem(context, item),
        );
      },
    ),
  );
}
```

- [ ] **Step 4: Run static analysis on the page file**

Run:

```bash
flutter analyze lib/modules/movies/movies_page.dart
```

Expected: PASS with no undefined imports or helper symbol errors.

### Task 4: Add Unavailable-Tap Handling

**Files:**
- Modify: `lib/modules/movies/movies_page.dart`
- Modify: `lib/modules/movies/movies_controller.dart`
- Test: `test/modules/movies/movies_controller_test.dart`

- [ ] **Step 1: Gate navigation through the controller playability helper**

Update the page open handler:

```dart
void _openItem(BuildContext context, MediaItem item) {
  if (!controller.canOpenMovie(item)) {
    Get.snackbar(
      'Not Available',
      'This movie is not available right now.',
    );
    return;
  }

  Get.toNamed(
    AppRoutes.fullscreenPlayer,
    arguments: {
      'items': [item],
      'currentId': item.id,
    },
  );
}
```

- [ ] **Step 2: Keep the playability check narrow**

Do not add artwork or subtitle checks. Keep `canOpenMovie()` limited to source metadata:

```dart
bool canOpenMovie(MediaItem item) {
  final streamUrl = item.metadata['streamUrl']?.toString();
  final directSource = item.metadata['directSource']?.toString();
  final streamId = item.metadata['streamId']?.toString();
  return (streamUrl != null && streamUrl.isNotEmpty) ||
      (directSource != null && directSource.isNotEmpty) ||
      (streamId != null && streamId.isNotEmpty);
}
```

- [ ] **Step 3: Run the controller tests again**

Run:

```bash
flutter test test/modules/movies/movies_controller_test.dart
```

Expected: PASS, including the playability checks.

### Task 5: Final Verification

**Files:**
- Modify: `lib/modules/movies/movies_controller.dart`
- Modify: `lib/modules/movies/movies_page.dart`
- Test: `test/modules/movies/movies_controller_test.dart`

- [ ] **Step 1: Run formatter on the touched files**

Run:

```bash
dart format \
  lib/modules/movies/movies_controller.dart \
  lib/modules/movies/movies_page.dart \
  test/modules/movies/movies_controller_test.dart
```

Expected: Files format successfully with no syntax errors.

- [ ] **Step 2: Run the focused tests**

Run:

```bash
flutter test test/modules/movies/movies_controller_test.dart
```

Expected: PASS.

- [ ] **Step 3: Run diagnostics on the edited files**

Run IDE diagnostics for:

```text
lib/modules/movies/movies_controller.dart
lib/modules/movies/movies_page.dart
test/modules/movies/movies_controller_test.dart
```

Expected: No new analyzer errors introduced by the implementation.

- [ ] **Step 4: Run targeted analysis**

Run:

```bash
flutter analyze \
  lib/modules/movies/movies_controller.dart \
  lib/modules/movies/movies_page.dart
```

Expected: PASS.

- [ ] **Step 5: Manual verification in the app**

Verify all of the following:

```text
1. Movies page shows a featured carousel with exactly 3 cards.
2. Featured cards show ratings when ratings exist.
3. The page contains Trending Movies, New This Week, Mystery & Thriller,
   Romantic Comedies, and Top Rated sections.
4. The bottom movie grid shows 3 cards per row in the target layout.
5. Tapping a playable movie opens the fullscreen player route.
6. Tapping a non-playable movie shows "This movie is not available right now."
7. Empty-state behavior still works when no movies exist.
```

## Self-Review

- Spec coverage: The plan covers the 3-card featured carousel, movie-only sections, metadata-first curation with fallback backfill, ratings on cards, unavailable-tap feedback, and the 3-column grid.
- Placeholder scan: The plan avoids `TODO`/`TBD` placeholders and gives exact files, commands, and code snippets for each implementation step.
- Type consistency: The plan consistently uses `featuredMovies`, `trendingMovies`, `newThisWeekMovies`, `mysteryThrillerMovies`, `romanticComedyMovies`, `topRatedMovies`, and `canOpenMovie`.
