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