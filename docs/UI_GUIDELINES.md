# UI Guidelines

## Design Goals

The app should feel:

- Modern
- Fast
- Clean
- Premium
- Easy to use

---

## Colors

Support:

- Light Theme
- Dark Theme

Use semantic colors:

Primary

Secondary

Surface

Background

Error

Success

Warning

Avoid hardcoding colors inside widgets.

---

## Spacing

Use consistent spacing.

Recommended:

4

8

12

16

24

32

48

Use spacing constants.

---

## Border Radius

Small

8

Medium

12

Large

20

Cards

16

Dialogs

20

---

## Typography

Hierarchy

Display

Headline

Title

Body

Caption

Keep font sizes consistent.

---

## Icons

Use one icon family throughout the app.

Keep icon sizes consistent.

Common sizes:

16

20

24

32

48

---

## Cards

Cards should contain:

Image

Title

Subtitle

Optional Actions

Keep shadows subtle.

---

## Buttons

Primary

Secondary

Text

Danger

Loading buttons should show progress.

---

## Animations

Keep animations short.

Recommended:

200–300 ms

Use smooth transitions.

Avoid excessive animations.

---

## Navigation

### Mobile

Bottom Navigation

Drawer

Back Button

### Tablet

Navigation Rail

Side Menu

### TV

Focus navigation

Large buttons

Large cards

Visible focus indicator

Remote-friendly layout

### Desktop

Resizable windows

Sidebar

Keyboard shortcuts

Hover effects

---

## Responsive Layout

Small

Phone

Medium

Tablet

Large

Desktop

Extra Large

TV

Do not hardcode widths.

Use responsive layouts.

---

## Images

Cache posters.

Lazy load logos.

Use placeholders while loading.

---

## Accessibility

Support:

Large text

Screen readers

High contrast

Keyboard navigation

Focus indicators

---

## General Rules

Keep screens uncluttered.

Avoid nested scrolling.

Use loading indicators.

Always handle empty states.

Always handle errors.

Provide pull-to-refresh where appropriate.

Consistency is more important than complexity.

---

## Live TV UI Specifications

### Channel Cards

Channel cards are the primary visual element for browsing live TV content.

**Card Layout:**

- Logo (64x64 default, scalable)
- Channel name (1 line, ellipsis)
- Current program name (1 line, ellipsis)
- Provider badge (small chip)
- Favorite button (top-right overlay)
- Channel number (top-left overlay)
- Live indicator (top-left, red dot + "LIVE" text)
- HD/FHD/UHD badge (top-right, above favorite)
- Resolution badge (if available in metadata)

**Card Grid:**

- Phone: 2 columns
- Tablet: 3 columns
- Desktop: 4 columns
- TV: 5 columns
- Item aspect ratio: 0.75

### Grid Layouts

The Live TV browser supports multiple view modes:

- **Grid View**: Default, cards in a responsive grid
- **List View**: Single-column list with channel logos and info
- **Compact View**: Smaller cards for dense browsing
- **TV View**: Large focusable cards optimized for remote navigation
- **Desktop View**: Wide grid with hover effects

### Navigation Patterns

- **Phone**: Bottom Navigation + AppBar
- **Tablet**: Navigation Rail + AppBar
- **Desktop**: Sidebar + AppBar
- **TV**: Focus-based navigation with remote controls

### Channel Details

The channel detail screen provides comprehensive metadata:

- Large logo/artwork
- Channel name and number
- Description (if available)
- Current program banner
- Upcoming programs section
- Provider badge
- Metadata row (resolution, language, country, genres)
- Favorite toggle button
- Share button (placeholder)
- Play button (disabled until playback is implemented)

### Provider Overview

Provider statistics are displayed as a summary grid:

- Provider name
- Channel count
- Provider type icon
- Tap to filter channels by provider

### Category Navigation

Categories are displayed as chips that can be scrolled horizontally:

- Sports
- Movies
- News
- Kids
- Music
- Entertainment
- International
- Custom Groups
- Recently Added
- Favorites
- All Channels

### Favorite Management

Favorites are managed through:

- Favorite button on each channel card (toggle)
- Favorites tab showing all favorited channels
- Sort options: alphabetical, recently added, provider, country
- Recently favorited section on home screen

### Loading & Empty States

- Skeleton loaders during initial data fetch
- Shimmer placeholders for images
- Progress indicators for async operations
- EmptyLibrary widget for no-data scenarios
- ErrorView widget for error states with retry action

### Performance Guidelines

- Lazy load channel cards in grid views
- Cache channel logos using appropriate image caching
- Use pagination for large channel lists
- Avoid unnecessary rebuilds with Obx/GetBuilder
- Virtualized lists for long channel collections

---

## EPG UI Specifications

### TV Guide

The TV Guide is the primary EPG browsing screen. It displays a grid of channels with their current and upcoming programs across a configurable time window.

**Layout:**

- Channel column on the left (logo, name, number, provider badge, favorite button)
- Timeline grid on the right (horizontal scrolling)
- Current time indicator (red vertical line)
- Program cells with title, time, progress bar, and badges

**Responsive behavior:**

- Phone: Single channel list with program details
- Tablet: Split view with channel list and timeline
- Desktop: Full guide grid with horizontal scrolling
- TV: Large focusable grid with remote navigation

### Timeline View

The Timeline View displays a single channel's program schedule across a configurable time window.

**Features:**

- Horizontal scrolling timeline
- Time ruler with hour markers
- Current time indicator
- Program cells with progress indicators
- Past, current, and future program sections
- Infinite horizontal scrolling for loading more data

**Time Window Options:**

- 30 minutes
- 1 hour
- 2 hours
- 4 hours
- 6 hours
- 12 hours
- 24 hours

### Program Details

The Program Details screen shows comprehensive information about a selected program.

**Layout:**

- Poster/backdrop image at the top
- Title and subtitle
- Live indicator (if currently playing)
- Progress bar with remaining time (if currently playing)
- Metadata rows: start time, end time, duration, channel, episode, season
- Cast and directors
- Genre tags
- Rating
- Description
- Action buttons: Favorite, Remind, Record (future), Play (disabled)

### Channel Timeline

The Channel Timeline displays a single channel's full schedule with infinite horizontal scrolling.

**Features:**

- Past programs (grayed out)
- Current program (highlighted with progress)
- Future programs (normal)
- Navigation buttons: Now, Morning, Afternoon, Evening, Tomorrow, Specific Date
- Load more on scroll

### Mini Guide

The Mini Guide is a floating guide widget designed for overlay use.

**Features:**

- Compact layout showing next 5-10 programs
- Time labels
- Live badge for current programs
- "View All" action to open full guide
- Intended for use while video plays (future integration)

### Guide Search

The Guide Search screen allows users to search and filter programs.

**Search Fields:**

- Program name
- Channel
- Genre
- Cast
- Director
- Category
- Language

**Filters:**

- Provider
- Genre
- Category
- Favorites only
- HD only
- Country
- Language

**Sorting:**

- Channel number
- Alphabetical
- Favorites first
- Recently watched
- Provider

### Time Navigation

Quick navigation buttons for jumping to specific time ranges:

- Now (current time)
- Morning (6:00 - 18:00)
- Afternoon (12:00 - 00:00)
- Evening (18:00 - 06:00)
- Tomorrow (next day)
- Specific Date (date picker)

### Loading & Empty States

**Loading:**

- Skeleton placeholders during initial guide load
- Shimmer effect for program cards
- Progress indicators for async operations

**Empty:**

- No Guide: Display when no EPG data is available
- No Channels: Display when guide has no channels
- No Programs: Display when no programs match filters
- Guide Unavailable: Display when guide source is unavailable

**Error:**

- Guide parsing errors with retry action
- Missing metadata fallback UI
- Offline mode indicator
- Provider unavailable message

### TV Navigation

**Remote Controls:**

- D-pad navigation between channels and programs
- OK/Select to open program details
- Back to return to guide grid
- Guide button to toggle mini guide overlay
- Channel up/down for quick channel switching

**Focus Management:**

- Visible focus indicator on all interactive elements
- Large touch targets (minimum 48x48 dp)
- Focus moves in logical grid order
- Smooth focus animations

### Responsive Design

**Phone:**

- Single column layout
- Bottom navigation
- Compact program list
- Mini guide as overlay

**Tablet:**

- Split view: channel list + timeline
- Navigation rail
- Medium program cards

**Desktop:**

- Full guide grid with horizontal scrolling
- Sidebar navigation
- Hover effects on program cells
- Keyboard shortcuts for navigation

**Android TV / Apple TV:**

- Focus-based navigation with remote
- Large focusable cards
- Visible focus indicator
- Remote-friendly layout
- Large text and controls

### Animations

- Smooth timeline scrolling (200-300ms)
- Fade transitions between screens
- Focus animations for TV navigation
- Program selection highlight animation
- Progress bar smooth updates

### Accessibility

- Screen reader support for all EPG elements
- Keyboard navigation (Tab, Arrow keys, Enter)
- High contrast mode support
- Large text support
- Semantic labels for program cells
- Live region announcements for time updates

---

## Home Dashboard

The Home screen is the central hub of the application after login. It provides a personalized dashboard that transforms the application from a provider configuration tool into a premium streaming platform.

### Navigation

The application uses a bottom navigation bar with five tabs:

| Tab | Route | Description |
| --- | --- | --- |
| Home | `/home` | Personalized dashboard |
| Live TV | `/live-tv` | Live TV browsing |
| Library | `/library` | Movies, Series, Favorites, Downloads, History |
| Search | `/search` | Global search |
| Settings | `/settings` | All settings including Media Sources |

Providers are moved from the bottom navigation into Settings under "Media Sources".

### Dashboard Sections

The Home dashboard includes the following sections, each independently refreshable:

1. **Greeting** — Displays user avatar, name, current workspace, and time-based greeting (Good Morning / Good Afternoon / Good Evening)
2. **Quick Actions** — Grid of shortcut cards for common actions (Watch Live TV, Browse Movies, Browse Series, Search, TV Guide, Downloads, Media Sources, Settings)
3. **Provider Summary** — Compact card showing connected provider count and last sync time
4. **Continue Watching** — Horizontal carousel of content with active watch progress
5. **Live TV** — Horizontal list of recently watched and popular channels
6. **Movies** — Trending, Recently Added, and Continue Watching rows
7. **Series** — Continue Watching, Recently Added, and Popular rows
8. **TV Guide** — Currently Airing, Next Programs, and Guide Shortcut
9. **Favorites** — Favorite Channels, Movies, and Series
10. **Recently Added** — Latest content from all providers
11. **Recently Played** — Playback history across channels, movies, and series
12. **Downloads** — Downloaded content, download queue, and storage usage

### Empty States

Every section must have a polished empty state. No blank screens are allowed. Empty states should:

- Display a friendly icon and message
- Guide users toward adding media sources
- Provide an "Add Media Source" button where applicable
- Include a "Learn More" placeholder where appropriate

If no providers are connected, the dashboard displays a Welcome Card instead of an empty dashboard:

- Welcome message
- Explanation of what the app does
- Feature preview chips (Live TV, Movies, Series, TV Guide, Favorites, Downloads)
- Primary action: "Add Media Source" button
- Secondary action: "Learn More" placeholder

### Responsive Layout

The Home dashboard adapts to all screen sizes:

- **Phone**: Single column with bottom navigation
- **Tablet**: Navigation rail with optimized spacing
- **Desktop**: Sidebar navigation with wider content area
- **Android TV / Apple TV**: Focus-based navigation with large cards and visible focus indicators
- **Landscape**: Adjusted grid layouts for wider viewports

### Loading States

- Skeleton cards during initial data fetch
- Placeholder rows for content that is loading
- Animated shimmer effects for image placeholders
- Indeterminate progress indicators for async operations

### Reusable Components

The following reusable components are used throughout the Home dashboard:

| Component | Purpose |
| --- | --- |
| `GreetingHeader` | Displays greeting, user avatar, name, and workspace |
| `DashboardSection` | Wraps dashboard sections with title, subtitle, and divider |
| `MediaCarousel` | Horizontal scrolling carousel for media items |
| `ContinueWatchingRow` | Horizontal row for continue watching items |
| `QuickActionGrid` | Grid of quick action cards |
| `ProviderSummaryCard` | Compact summary of connected providers |
| `EmptyLibraryCard` | Polished empty state for library sections |
| `FeatureCard` | Feature preview card for welcome screen |
| `RecentActivityCard` | Row card for recent activity items |
| `StorageCard` | Storage usage indicator with progress bar |

---

## Series Experience Guidelines

### Visual Language & Components

1. **`SeriesCard`**:
   - 2:3 vertical poster card with rounded corners and subtle shadow.
   - Overlays: rating badge (gold star), seasons count badge, favorite toggle, completed checkmark, and linear progress bar for in-progress series.
   - TV Remote Focus: scale transformation (`1.05x`) and primary colored border.

2. **`ContinueWatchingSeriesCard`**:
   - 16:9 widescreen landscape card showcasing the specific episode thumbnail.
   - Displays series title, episode title, season/episode identifier (`S02E04`), remaining duration, and progress bar with gradient tint.

3. **`EpisodeCard`**:
   - Multi-state list item with episode thumbnail, duration badge, watched status checkmark, and "NEXT" / "PLAYING" badge.
   - Supports active playback highlighting and TV focus.

4. **`NextEpisodeOverlay`**:
   - Non-intrusive floating card in bottom-right corner of player.
   - Displays 10s animated countdown, next episode thumbnail, and "Play Now" / "Cancel" actions.

5. **`SkipIntroButton`**:
   - Semi-transparent glassmorphic pill button appearing automatically during intro segments.