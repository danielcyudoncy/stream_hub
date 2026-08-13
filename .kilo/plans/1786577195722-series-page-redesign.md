# Series Page UI Redesign Plan

## Branch
`feature/series-page-redesign` created from main with the series info URL encoding + session credential fixes cherry-picked onto it. Main is reset to `origin/main`.

## Goal
Redesign the Series page (`/series` route) to include a featured carousel, genre/category sections, a 3-column grid, and rating badges on cards.

## Assumption to verify
You asked for the carousel to show "current movies" on the Series page. I will populate it with **featured series** (top-rated / recently updated). If you actually want a mixed movie+series carousel here, that changes the data source — confirm before implementation.

## Changes

### 1. `lib/modules/series/series_controller.dart`
Add computed RxLists for each section. Load all series once, then derive:
- `featuredSeries` — top 3 by `rating` (fallback to `updatedAt`)
- `trendingSeries` — top 15 sorted by `updatedAt` descending
- `newThisWeekSeries` — `createdAt` within last 7 days
- `mysteryThrillerSeries` — genres contain "mystery" or "thriller" (case-insensitive)
- `romComSeries` — genres contain "romance" or "comedy" (case-insensitive)
- `topRatedSeries` — non-null `rating`, sorted descending, top 15

Keep existing `series` list for the bottom grid.

### 2. `lib/modules/series/series_page.dart`
Replace the simple grid with:
- Featured carousel at top using `MediaCarousel` (`itemWidth: 100`, 3 cards visible)
- `MediaSection` widgets for each category with "See All" trailing buttons
- `SliverGrid` with `SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3)` instead of `maxCrossAxisExtent: 200`

Section order:
1. Featured (carousel)
2. Trending Series
3. New This Week
4. Mystery & Thriller
5. Rom-Coms
6. Top Rated
7. All Series (3-column grid)

### 3. `lib/shared/widgets/media_poster_card.dart`
Add rating display below title when `item.rating != null`:
- Small `Row` with star icon + rating text (e.g. `★ 8.5`)
- Use `AppTypography.getCaption` with `scale: 0.8` and `colorScheme.primary`

### 4. Tests
- Add `series_controller_test.dart` covering the new computed lists and edge cases (empty genres, null ratings, date filtering)
- No existing series_page widget tests to update

## Validation
- `flutter analyze`
- Run new `series_controller_test.dart`
- Manual UI check: 3 cards per row in grid, ratings visible, carousel scrolls, sections populate correctly
