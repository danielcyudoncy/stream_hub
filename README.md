# StreamHub Pro

A modern, cross-platform IPTV player built with Flutter. Connect your own IPTV
providers and enjoy Live TV, Movies, Series, and a full TV Guide through one
fast, provider-independent media platform.

StreamHub Pro **does not provide any content**. It lets you connect and play
content from IPTV sources you already subscribe to (or public free sources),
turning them into a unified, offline-first experience.

---

## Highlights

- **Multi-provider support** — M3U URL/file, Xtream Codes API, Stalker Portal
  (MAC), and XMLTV EPG guides, plus a provider-free **Free Live TV** catalog.
- **Unified media library** — every source is normalized into a single
  `MediaItem` model; Live TV, Movies, Series, and EPG live side-by-side.
- **Provider-independent playback pipeline** — all streams pass through a
  Stream Engine that produces `PlayableSession` objects. The player never
  receives a raw provider URL.
- **Premium player features** — picture-in-picture, subtitles, multiple audio
  tracks, playback speed, resume playback, next-episode autoplay, and skip-intro.
- **Offline-first** — Hive-backed local caching keeps the catalog, favorites,
  history, and downloaded content available without a connection.
- **TV & desktop ready** — dedicated D-pad / remote focus navigation, plus
  responsive layouts for phone, tablet, desktop, and TV.
- **Premium extras** — downloads, Firestore cloud sync, multi-profile support,
  and parental controls.

---

## Features

### Live TV

- Channel categories, favorites, search, and recently watched
- Channel switching (next/previous) and instant playback
- Channel details page with provider badges
- Multi-view mode with up to 4 simultaneous channels

### TV Guide (EPG)

- Full timeline guide with current-time indicator
- Mini guide, program details, and channel timelines
- Guide search across programs, channels, genres, cast, and more
- Filters and sorting (provider, genre, favorites, HD, country, language)
- Time navigation (Now, Morning, Afternoon, Evening, Tomorrow, specific date)
- Timeline zoom (30 min → 24 h)
- Real XMLTV programs enrich channels automatically

### Free Live TV

- Provider-free curated catalog (IPTV-org public playlists + bundled feeds)
- Automatic multi-stream failover when a stream stalls or dies
- "Working only" reachability filtering with cached stream health
- Featured carousel, curated categories/countries/regions, favorites
- Standalone experience that never requires an IPTV subscription

### Movies & Series

- Curated home hubs with hero spotlight and genre carousels
- Rich detail pages: backdrop, cast, director, plot, related titles
- Genre browsing with search, provider filter, and multi-criteria sorting
- Continue Watching with progress indicators and resume playback
- Deterministic next-episode traversal and series-wide watch progress
- Skip Intro and Autoplay Next overlays

### Player

- media_kit (libmpv) primary engine; VLC fallback; native ExoPlayer and
  experimental IJK backends on Android
- Picture-in-picture, subtitles, audio-track selection, playback speed
- Aspect-ratio control, buffer monitoring, structured error recovery

### Premium

- **Downloads** — queue with pause/resume/cancel/retry
- **Cloud Sync** — per-user Firestore sync, offline-first
- **Profiles** — up to 5 profiles with scoped data isolation
- **Parental Controls** — SHA-256 PIN-gated playback across all pipelines

### Developer Tools

Built-in diagnostics for testing providers and streams:

- Playback Test, Provider Test, Stream Test tools
- Per-stage diagnostics reports (detection → negotiation → playback)

---

## Supported Providers

| Provider | Type | Status |
| ---------- | ------ | -------- |
| M3U | URL / local file | Complete |
| Xtream Codes | `player_api.php` (live, VOD, series) | Complete |
| Stalker Portal | MAC login | Complete |
| XMLTV | EPG guide enrichment | Complete |
| Free Live TV | Public catalogs (no provider) | Complete |
| Jellyfin / Plex / Emby / TVHeadend / HDHomeRun | — | Stubbed / planned |

---

## Architecture

StreamHub follows a layered, provider-independent architecture:

UI (GetX widgets)
  ↓
Controllers
  ↓
Repositories
  ↓
Media Engine → Media Library
  ↓
Stream Engine (sessions, auth, headers, validation)
  ↓
Playback Engine
  ↓
Player Adapters (MediaKit / VLC / ExoPlayer)
  ↓
Native Player

Every provider implements a shared adapter interface and produces normalized
media models. All playback and downloads flow through the Stream Engine, which
delivers only `PlayableSession` objects — the player never touches provider
URLs or credentials.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for full details.

---

## Tech Stack

- **Framework:** Flutter / Dart (SDK ^3.11.5)
- **State management & DI:** GetX
- **Local storage:** Hive (+ SQLite for future large datasets)
- **Cloud:** Firebase (Auth, Firestore, Crashlytics, Analytics, Messaging,
  Remote Config) + Google Sign-In
- **Playback:** media_kit (libmpv), flutter_vlc_player, Media3/ExoPlayer
- **Networking:** DoH-aware HTTP client with resilient DNS fallback

---

## Platforms

| Platform | Status |
| ---------- | -------- |
| Android (incl. Android TV / leanback) | Supported |
| iOS | Supported |
| macOS | Supported |
| Windows | Supported |
| Linux | Supported |
| Web | In progress |

---

## Getting Started

### Requirements

- Flutter SDK (see `pubspec.yaml` for the Dart SDK constraint)
- Firebase project configured (for auth, crashlytics, and cloud features)

### Setup

```bash
# 1. Install dependencies
flutter pub get

# 2. Configure Firebase (creates firebase_options.dart, google-services.json, etc.)
flutterfire configure

# 3. Run the app
flutter run
```

Optional playback engines on Android:

```bash
# Build and vendor the experimental IJKPlayer engine
tools/streamhub-build.sh
tools/ijkplayer/vendor.sh
```

### Tests

```bash
# Unit & widget tests
flutter test

# Integration tests (macOS)
flutter test integration_test -d macos
```

The repository ships ~760 unit/widget tests plus on-device integration suites
for real playback pipelines (Android and macOS).

---

## Repository Structure

lib/
  core/       # themes, routing, media/stream/playback engines, IPTV core,
              # network (DoH), logging, services
  data/       # models, repositories, provider adapters (M3U/Xtream/Stalker/
              # XMLTV/Free TV), parsers, metadata engine
  modules/    # feature modules (home, live_tv, free_live_tv, movies, series,
              # player, epg, downloads, settings, profiles, ...)
  shared/     # reusable widgets, dialogs, TV focus system
  database/   # storage layer
test/         # unit & widget tests
integration_test/  # on-device playback and TV navigation tests
tools/        # IJKPlayer build/vendor scripts
packages/     # vendored patched packages (flutter_vlc_player_platform_interface,
              # media_kit_video)

---

## Documentation

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — architecture and design system
- [docs/API.md](docs/API.md) — provider and stream API contracts
- [docs/UI_GUIDELINES.md](docs/UI_GUIDELINES.md) — UI/UX standards
- [docs/ROADMAP.md](docs/ROADMAP.md) — feature roadmap
- [docs/PLAYBACK_ENGINEERING.md](docs/PLAYBACK_ENGINEERING.md) — player engine decisions
- [docs/IPTV Architecture Research.md](docs/IPTV%20Architecture%20Research.md) — provider research

---

## Legal / Disclaimer

StreamHub Pro does not host, distribute, or provide any television channels,
movies, series, or other media content. Users connect their own IPTV sources
and are responsible for ensuring they have the right to access and play the
content they use with this application.

StreamHub Pro is not affiliated with, endorsed by, or connected to any IPTV
provider or media brand referenced within the repository.
