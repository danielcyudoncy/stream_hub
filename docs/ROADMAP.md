# Roadmap

## Phase 1

Project Foundation

- Flutter setup
- GetX
- Hive
- Firebase
- Themes
- Routing
- Splash Screen
- Settings Module
- Provider Manager
- User Profile
- About Section
- Legal Pages
- Storage Management
- Cache Management
- Local Preferences
- Theme Switching
- Language Selection
- Provider CRUD
- Search / Filter / Sort

---

## Phase 2A

Media Platform Core

- MediaSource abstraction
- MediaSourceManager
- MediaSourceRegistry
- MediaSourceFactory
- MediaEngine
- MediaCatalog
- MediaLibrary
- MediaItem base model
- Specialized media models
- PlayableStream
- StreamResolver interface
- Merge engine interfaces
- Search engine interfaces
- Filter engine interfaces
- Sort engine interfaces
- Sync engine interfaces
- Health monitoring interfaces
- Event bus system
- Service interfaces
- Repository interfaces
- Dependency injection registration
- Media source stubs (all supported types)

---

## Phase 2B

M3U Support

- [x] M3U URL parsing
- [x] M3U file parsing
- [x] Category loading
- [x] Channel loading
- [x] Playlist caching
- [x] Streaming parser
- [x] Validation
- [x] Statistics
- [x] Download service with retry/auth/cancellation
- [x] Media Catalog integration
- [x] Health monitoring
- [x] Refresh support

---

## Phase 2C

XMLTV Media Source & Metadata Engine

- [x] XMLTV models
- [x] XMLTVDownloadService
- [x] XMLTVParser (streaming)
- [x] XMLTVMediaSource
- [x] ChannelMatcher
- [x] EPGEngine and TimelineEngine
- [x] XMLTV services (cache, merge, statistics, health, search, sync)
- [x] Updated XMLTV stub to delegate to real implementation
- [x] Updated media source factory
- [x] Updated repositories (CatalogRepository, SearchRepository)
- [x] Updated docs (API.md, ARCHITECTURE.md)
- [x] 22 XMLTV tests passing

---

## Phase 2D

Metadata Aggregation & Unified Media Library

- [x] MetadataProvider abstract interface
- [x] MetadataSourceType enum (xmltv, tmdb, tvmaze, imdb, trakt, fanart, provider, local, custom)
- [x] MetadataEngine (collect, merge, normalize metadata)
- [x] MetadataMergeEngine (merge duplicates, resolve conflicts, configurable strategies)
- [x] ArtworkService (poster, backdrop, logo, thumbnail selection, fallback)
- [x] SearchIndex (full-text search index)
- [x] SearchEngine (search, instantSearch, suggest, recent, popular, autocomplete)
- [x] CollectionEngine (genres, recently added, favorites, downloads, continue watching, live now, upcoming)
- [x] HistoryService (opened, played, finished, search history, provider usage)
- [x] FavoriteService (favorites referencing MediaItem, not provider)
- [x] RecommendationService (interfaces only: similar, becauseYouWatched, continueWatching, recommended)
- [x] MediaIndex (fast lookup by ID, title, provider, category, genre, language)
- [x] CanonicalMediaItem (canonical model with provider ownership, metadata sources, artwork sources)
- [x] MediaLibraryImpl (unified library, single data source for UI)
- [x] Concrete metadata providers (XMLTV, TMDB, TVMaze, IMDb, Trakt, Fanart, Provider Native, Local, Custom)
- [x] Updated repositories (MediaRepository, CatalogRepository, SearchRepository, HistoryRepository, FavoriteRepository)
- [x] Metadata events (MetadataUpdatedEvent, ArtworkUpdatedEvent, SearchIndexedEvent, LibraryUpdatedEvent, CollectionUpdatedEvent)
- [x] Updated docs (ARCHITECTURE.md, API.md)
- [x] 52 Phase 2D tests passing

---

## Phase 3B

EPG Experience

- [x] TV Guide
- [x] Timeline View
- [x] Program Details
- [x] Channel Timeline
- [x] Guide Search
- [x] Mini Guide
- [x] Current Time indicator
- [x] Timeline navigation (30min, 1h, 2h, 4h, 6h, 12h, 24h)
- [x] Channel column with logo, name, number, provider badge, favorite
- [x] Program cells with title, time, duration, progress, badges
- [x] Current program highlight with progress and remaining time
- [x] Upcoming program display
- [x] Program details with full metadata
- [x] Guide search (program name, channel, genre, cast, director, category, language)
- [x] Filters (provider, genre, category, favorites, HD, country, language)
- [x] Sorting (channel number, alphabetical, favorites, recently watched, provider)
- [x] Time navigation (Now, Morning, Afternoon, Evening, Tomorrow, Specific Date)
- [x] Responsive design (phone, tablet, desktop, TV)
- [x] TV optimization (remote navigation, focus management, keyboard navigation)
- [x] Virtualized scrolling and lazy loading
- [x] Timeline caching
- [x] Image caching
- [x] Skeleton placeholders for loading states
- [x] Empty states (no guide, no channels, no programs, guide unavailable)
- [x] Error states (parsing errors, missing metadata, offline, provider unavailable)
- [x] Smooth animations (timeline scrolling, fade transitions, focus animations)
- [x] Accessibility (screen readers, keyboard navigation, high contrast, large text)
- [x] Reminder architecture (ReminderService, ReminderRepository, ReminderModel)
- [x] Recording architecture (RecordingService, RecordingRepository, RecordingModel)
- [x] Catch-up architecture (CatchUpModel)

---

## Phase 3 — Live TV

- [x] Categories
- [x] Channels (tap-to-play via PlaybackEngine)
- [x] Favorites (wired to FavoriteRepository)
- [x] Search
- [x] Recently Watched (wired to HistoryRepository)
- [x] Direct channel playback from category list
- [x] Channel switching (next/previous)
- [x] Channel details page with working play button
- [x] M3U stream resolution (M3UStreamResolver)

---

## Phase 3Z — Stream Engine

Provider-independent playback and download preparation pipeline.

- [x] Stream Engine orchestration (`StreamEngine`)
- [x] ProviderSession model and lifecycle (create, reuse, refresh, invalidate)
- [x] ProviderSessionFactoryRegistry + factories (M3U, Xtream, Stalker, Bearer server)
- [x] SessionManager + encrypted SessionCache (Hive box `provider_sessions`)
- [x] AuthenticationEngine + AuthenticationProvider SPI (M3U, Xtream, Stalker, Bearer token)
- [x] StreamResolver SPI + DefaultStreamResolver (relative URLs, redirects, DRM, backups)
- [x] HeaderEngine (UA, Referer, Origin, Authorization, Bearer, Cookies, custom)
- [x] CookieManager (per-provider cookies, expiry, restore)
- [x] UrlNormalizer (canonicalization, query dedup, user-info extraction, relative resolution)
- [x] StreamValidator (URL, scheme, expiry, header integrity, HTTP probes)
- [x] PlayableSessionFactory (immutable session assembly)
- [x] StreamCache (TTL in-memory session cache)
- [x] FailoverManager (primary + backup URL selection)
- [x] StreamHealthMonitor (availability, latency, failures, bitrate)
- [x] DownloadPreparationService (PreparedDownload, file naming)
- [x] StreamEventBus + lifecycle events
- [x] SensitiveDataRedactor + DataEncryption (no credentials in logs/disk)
- [x] StreamTaskManager (background session refresh, persists refreshed sessions)
- [x] Repositories (StreamRepository, AuthenticationRepository, StreamCacheRepository)
- [x] Controllers (SessionController, PlaybackSessionController, StreamHealthController, AuthenticationController)
- [x] StreamEngineBinding (DI graph, wired before MediaBinding)
- [x] Player integration (PlaybackEngine.playFromStreamEngine, PlayerAdapter.playSession, MediaKit header/cookie/bearer injection)
- [x] PlayerController resolves through Stream Engine (no raw provider URLs)
- [x] Docs updated (ARCHITECTURE.md, API.md)
- [x] 90 Stream Engine tests passing (190 total)

---

## Phase 3ZZ — IPTV Core & Playback Negotiation Engine

Provider-independent analysis, negotiation, and diagnostics layer that sits
between the Stream Engine and the Playback Engine.

- [x] `ProviderDetector` (M3U, Xtream, Stalker, XMLTV, local; transport; ZIP/GZIP compression)
- [x] `ProviderCapabilityAnalyzer` (normalized capability set; config overrides)
- [x] `PlaylistAnalyzer` (M3U classification, stats, header attributes, protocol distribution)
- [x] `StreamNegotiationEngine` (protocol → capability → player → header → analysis)
- [x] `ProtocolDetector` / `CapabilityDetector` / `PlayerNegotiator` / `HeaderNegotiator`
- [x] `StreamAnalyzer` (codec, resolution, bitrate, DRM, HLS/DASH variants)
- [x] `StreamDiagnosticsBuilder` + `StreamDiagnosticsReport` (steps, root cause, timings)
- [x] `ErrorRecoveryEngine` + `RecoveryResult` (actionable failure categories)
- [x] `DebugModeService` (reactive per-category toggles) + `DebugSessionLog`
- [x] `IptvCore` facade + `IptvCoreBinding` (DI, wired to real `StreamEngine`)
- [x] Test tools (`PlaybackTestTool`, `ProviderTestTool`, `StreamTestTool`)
- [x] Developer module (Settings → Developer Tools → Playback/Provider/Stream Test)
- [x] Docs updated (ARCHITECTURE.md)
- [x] 28 IPTV Core tests passing (243 total)

---

## Phase 3ZZZ — Xtream Provider & Unified VOD Playback

Full Xtream Codes panel support and VOD playback across providers.

- [x] `XtreamMediaSource` (live, VOD movies, series, live/VOD/series categories)
- [x] `XtreamStreamResolver` (direct live/VOD; series via `get_series_info`)
- [x] Xtream wired into `MediaSourceFactory` and `StreamEngineBinding`
- [x] Removed obsolete Xtream stub (`data/providers/stubs/xtream_source.dart`)
- [x] M3U movie/series classification (`M3UContentClassifier`: `tvg-type`, URL, group)
- [x] Library + Home movie/series cards playable via `AppRoutes.fullscreenPlayer`
- [x] Xtream export detection (`XtreamUrlDetector`): M3U `get.php`/`player_api.php` links sync via the Xtream JSON API
- [x] `XtreamMediaSource` falls back to `get_live_streams` when a panel ignores `action=live`
- [x] `XtreamMediaSource` parses bare top-level array payloads (non-standard panels)
- [x] Tolerant parsing of non-string metadata values (e.g. `backdrop_path` emitted as a list)
- [x] Account metadata (account created / expiry / trial / connections) captured from `user_info` and shown in provider details
- [x] Provider form auto-detects Xtream exports and prefills credentials
- [x] Tests: Xtream source + resolver, M3U classifier, export detection (291 total)

---

## Phase 4 — Player

- [x] Play streams via real media_kit integration (MediaKitPlayerAdapter)
- [x] Fullscreen video page with Video widget + overlays
- [x] Play/Pause/Resume/Stop/Seek/Replay
- [x] Channel switching (next/previous)
- [x] Error handling with retry UI
- [x] Loading/buffering/connecting overlay states
- [x] Current program info overlay (XMLTV subtitle via MediaItem)
- [x] Favorites toggle from player
- [x] Auto-record playback history for Continue Watching
- [x] Resume playback position (VOD resume state & threshold calculation)
- [ ] Picture-in-Picture
- [ ] Audio tracks
- [ ] Subtitles

---

## Phase 5 — Movies (VOD Experience)

- [x] Movie Library (Curated genre carousels, hero spotlight banner, top rated, recently added)
- [x] Dedicated Movie Details page (backdrop, metadata badges, cast list, director, plot summary, related movies)
- [x] Dedicated Movie Genre page (search, provider filter, favorites filter, multi-criteria sorting)
- [x] Continue Watching for Movies (progress indicators, remaining time calculation, resume playback)
- [x] Seamless VOD Playback integration with Stream Engine, PlaybackEngine, and PlayerController
- [x] TV navigation & remote focus support across all VOD screens
- [x] Unit, widget, and integration test coverage across all movie modules

---

## Phase 6

EPG

- TV Guide
- Current Program
- Next Program
- Refresh Guide

---

## Phase 7

Stalker Portal

- [x] MAC Login
- [x] Categories
- [x] Channels
- [x] Movies
- [x] Series
- [x] Network resilience — DNS-over-HTTPS fallback for fluxing provider hosts

---

## Phase 8

Premium Features

- Downloads
- Cloud Sync
- Profiles
- Parental Control

---

## Phase 9

TV & Desktop

- Android TV
- Apple TV
- macOS
- Windows

---

## Future

- Chromecast
- AirPlay
- AI Recommendations
- Voice Search
- Widgets
