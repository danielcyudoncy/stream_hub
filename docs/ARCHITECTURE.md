# Architecture

## Overview

StreamHub Pro uses a layered media platform architecture.

```
UI
 ↓
GetX Controllers
 ↓
Repository Layer
 ↓
Media Engine
 ↓
Media Source Manager
 ↓
Media Source Adapters
 ↓
Remote API / Local Storage
```

---

## Layers

### UI

Responsible for:

- Displaying data
- User interactions
- Navigation

Widgets should not contain business logic.

The UI never knows where content originated.
All screens consume `MediaEngine`, `MediaLibrary`, and `MediaCatalog`.
Provider type is an implementation detail hidden behind adapters.

---

### Controllers

Controllers:

- Manage screen state
- Call repositories
- Expose observable data
- Never call APIs directly

Controllers communicate with repositories and media services only.

---

### Repositories

Repositories are the bridge between controllers and services.

Responsibilities:

- Fetch data
- Cache data
- Decide local vs remote source

Examples:

- MediaRepository
- MediaSourceRepository
- CatalogRepository
- SearchRepository
- HistoryRepository
- FavoriteRepository

---

### Media Engine

The heart of the application.

Responsibilities:

- Merge content from all sources
- Index content
- Search
- Filter
- Sort
- Favorites
- History
- Continue Watching
- Recommendations
- Catalog updates
- Expose media library

UI communicates **only** with MediaEngine.

---

### Media Source Manager

Responsible for:

- Register sources
- Remove sources
- Initialize sources
- Sync sources
- Refresh sources
- Health monitoring
- Connection monitoring
- Statistics
- Return active source
- Return all sources
- Return enabled sources

---

### Media Source Registry

Registry for adapters.

Responsibilities:

- Register adapters
- Lookup adapters
- Remove adapters
- Enumerate adapters

---

### Media Source Adapters

Every media source is treated as a `MediaSource`.

Supported source types:

- M3U
- Xtream Codes
- Stalker Portal
- XMLTV
- Local Playlist
- Jellyfin
- Plex
- Emby
- TVHeadend
- HDHomeRun
- Custom
- Future

Each source returns the same unified models.

Example models:

- MediaItem
- Channel
- Movie
- Series
- Episode
- Program
- PlayableStream

#### M3U Adapter

The `M3UMediaSource` is the first concrete adapter. It:

1. Accepts a remote URL or local file path
2. Downloads the playlist via `M3UDownloadService`
3. Parses the content line-by-line via `M3UParser`
4. Validates structure and metadata
5. Builds `MediaItem` instances from `M3UChannel` entries
6. Caches results locally via `PlaylistCacheService`
7. Publishes channels through broadcast streams
8. Reports health and statistics

The adapter does not know about UI, player, or EPG. It only produces a `MediaCatalog` of channels and categories.

Xtream panel exports: when the configured URL is an Xtream export (`get.php` /
`player_api.php`, detected by `XtreamUrlDetector`), `M3UMediaSource` delegates
the entire sync to an internal `XtreamMediaSource` instead of downloading the
playlist. Getters and health/statistics delegate to the same source, so an M3U
provider pointing at a panel behaves exactly like an Xtream provider. This is
required for panels whose exports are far larger than their JSON API or that
refuse to serve the full export.

#### Catalog Flow

```
User adds M3U source
         ↓
MediaSourceManager.register()
         ↓
M3UMediaSource.initialize()
         ↓
M3UMediaSource.connect()
         ↓
M3UDownloadService.download()
         ↓
M3UParser.parse()
         ↓
PlaylistValidationService.validate()
         ↓
PlaylistStatisticsService.calculate()
         ↓
PlaylistCacheService.cachePlaylist()
         ↓
M3UMediaSource emits channelsStream
         ↓
CatalogRepository.upsertItems()
         ↓
MediaCatalog updated
```

---

### Free Live TV Adapter

Free Live TV is a **provider-free** source built on the normalized, live-verified
JSON API from `dearbulut/iptv` (IPTV Nexus). It requires no M3U/Xtream/Stalker
provider, no subscription, and no stream via the Stream Engine. It functions
independently and offline-first, coexisting with provider-based IPTV.

| Concern | Implementation |
|---------|----------------|
| Endpoints | `FreeTvApiConfig` — centralized endpoint constants pointing to `https://dearbulut.github.io/iptv/api/v1/` (`channels.online.json`, `countries.json`, `categories.json`) with gzip support |
| Remote Data | `FreeTvRemoteDataSource` / `DearbulutFreeTvRemoteDataSource` — Gzip-aware HTTP data source fetching online-verified channels, countries, and categories |
| DTOs & Models | `DearbulutChannelDto`, `DearbulutStreamDto`, `DearbulutHealthDto`, `FreeTvStream`, and `FreeTvChannel` |
| Normalizer / Mapper | `FreeTvMapper` — translates DTOs to canonical `FreeTvChannel` entities with localized country/region names, friendly category groupings, and stream health scores |
| Ingestion Pipeline | `FreeTvCatalogBuilder` — ingests JSON catalog, deduplicates multi-stream variants, unions categories/languages, and records pipeline diagnostics |
| Quality | `FreeTvQualityService` — excludes NSFW/junk/broken channels and assigns deterministic quality scores (0–100) with `recommended` (score ≥ 55) vs `valid` tiers |
| Model | `FreeTvChannel` → canonical `MediaItem` via `toMediaItem()` (consumed by `PlaybackEngine` / `PlayerController`); carries `streams`, `qualityScore` / `qualityTier` / `region` |
| Cache | `FreeTvRepository` — Hive boxes `free_tv_catalog` (TTL 12h), `free_tv_favorites`, `free_tv_recent` (capped at 20), `free_tv_reachability` (TTL 24h) |
| Reachability | Background live health data pre-populated from `dearbulut/iptv` and refined on-demand via `FreeTvReachabilityService` |
| Playback | Inline embedded player with automatic multi-stream fallback (Stream 1 ➔ 2 ➔ 3) |
| Session | `CustomProviderSessionFactory` — registered for `MediaSourceType.custom`; builds a credential-free `ProviderSession` from the direct stream URL, so Free TV flows through the standard Stream Engine pipeline (resolver → normalize → validate → `PlayableSession`) without any provider |

Key invariants:

- **Subscription independence** — never checks for active providers or
  subscriptions; remains usable offline via the local catalog cache.
- **JSON-first pipeline** — uses structured JSON data with stream-level health
  checks instead of heavy client-side M3U downloads and parsing.
- **Curated quality layer** — raw channels are never shown unfiltered.
  `FreeTvQualityService` applies strict exclusions and deterministic scoring,
  separating curated `recommended` channels (default) from `valid` channels.
- **Provider-independent playback** — channels map to `MediaItem` (via
  `toMediaItem()` using `MediaSourceType.custom`) and reuse the existing
  `PlaybackEngine` / `PlayerController` and embedded-player architecture. The
  `CustomProviderSessionFactory` makes `custom` a first-class session type, so
  the player still receives only a `PlayableSession` — never a raw URL.
- **Resilience & failover** — dead or rate-limited streams are retried
  sequentially against remaining candidates.
- **Reachability filtering (Working Only)** — `FreeTvReachabilityService`
  probes streams with the existing `HttpProbe` (DoH-aware HEAD-then-GET) and
  marks each channel `isWorking` when at least one stream URL answers 2xx or a
  playable media content-type. Results are cached in a `free_tv_reachability`
  Hive box (24h TTL) and surfaced to the UI as a "Working Only" toggle; the
  background probe targets the curated `recommended` tier (bounded) to keep
  startup fast and offline-first. Reachability never blocks catalog load.
- **Local caching** — catalog, favorites, and recently watched persist in
  dedicated Hive boxes.

The source exposes normalized `FreeTvChannel` objects only; it never reaches
the UI, player, or download engine directly.

---

### XMLTV Adapter

The `XMLTVMediaSource` is the XMLTV adapter. It:

1. Accepts a remote URL, local file path, or compressed (.xml.gz) guide
2. Downloads the guide via `XMLTVDownloadService`
3. Parses the content using a streaming XML parser via `XMLTVParser`
4. Validates structure and metadata
5. Matches XMLTV channels to existing channels via `ChannelMatcher`
6. Enriches the media catalog via `XMLTVMergeService`
7. Stores programmes in `EPGEngine` and `TimelineEngine`
8. Indexes programmes in `XMLTVSearchService`
9. Caches results locally via `XMLTVCacheService`
10. Publishes channels and programmes through broadcast streams
11. Reports health and statistics

#### XMLTV Flow

```
User adds XMLTV source
          ↓
MediaSourceManager.register()
          ↓
XMLTVMediaSource.initialize()
          ↓
XMLTVMediaSource.connect()
          ↓
XMLTVDownloadService.download()
          ↓
XMLTVParser.parse() (streaming)
          ↓
ChannelMatcher.matchChannels()
          ↓
XMLTVMergeService.enrichGuide()
          ↓
EPGEngine.storeGuide()
          ↓
TimelineEngine.loadGuide()
          ↓
XMLTVSearchService.indexGuide()
          ↓
XMLTVCacheService.cacheGuide()
          ↓
XMLTVMediaSource emits channelsStream and programsStream
          ↓
CatalogRepository.enrichWithXMLTV() / mergeXMLTVMetadata()
          ↓
MediaCatalog updated
```

#### Metadata Pipeline

XMLTV enriches the Media Catalog through a metadata pipeline:

1. **Download** — XMLTV guide is downloaded via HTTP/HTTPS or read from local storage
2. **Parse** — Streaming XML parser processes the guide incrementally
3. **Match** — ChannelMatcher matches XMLTV channels to existing media channels
4. **Merge** — XMLTVMergeService merges XMLTV metadata into existing catalog entries
5. **Store** — EPGEngine and TimelineEngine store and index programmes
6. **Index** — XMLTVSearchService indexes programmes for search
7. **Cache** — XMLTVCacheService persists the guide for offline use
8. **Enrich** — MediaCatalog is updated with enriched channel and programme data

The pipeline is designed so that:
- The UI never knows where metadata originated
- XMLTV metadata is transparently merged into existing catalog entries
- No UI changes are required to display XMLTV-enriched data
- The Media Catalog contains both channel data and TV guide data

---

### Media Catalog

Stores:

- Channels
- Movies
- Series
- Episodes
- Programs
- Categories
- Collections
- Media Items

Responsibilities:

- Merge duplicate content
- Track provider ownership
- Update metadata
- Enrich with XMLTV data
- Support XMLTV metadata pipeline

---

### Media Library

The unified library is the ONLY data source consumed by UI.

Exposes:

- Live TV
- Movies
- Series
- Episodes
- Programs
- Collections
- Continue Watching
- Favorites
- History
- Downloads
- Recently Added
- Recommended
- Trending (future)

The UI never knows provider types. Metadata providers enrich the catalog transparently.

---

### Canonical Media Item

Every provider contributes data to a single `CanonicalMediaItem`.

Fields:

- id
- title
- originalTitle
- sortTitle
- description
- tagline
- poster
- backdrop
- logo
- thumbnail
- genres
- language
- country
- rating
- runtime
- releaseDate
- cast
- crew
- studio
- providerOwnership
- metadataSources
- artworkSources
- trailers
- links

Provider ownership is tracked so a favorite remains valid across providers.

---

### Services

Services perform actual work.

Examples:

- CatalogService
- MetadataService
- MergeService
- SearchService
- FilterService
- SortService
- SourceService
- HealthService
- SyncService
- EventService
- ArtworkService
- HistoryService
- FavoriteService
- RecommendationService
- CollectionService
- IndexService
- PlaybackService
- BufferService
- SubtitleService
- AudioTrackService
- PlaybackHistoryService
- SessionService
- PlaybackAnalyticsService
- PlayerSettingsService

### Network Resilience

HTTP clients that talk to provider endpoints use a DNS-over-HTTPS (DoH)
fallback (`lib/core/network/doh_http_client.dart`).

Rationale: IPTV CDN hosts often "flux" — the DNS record briefly disappears or
the device resolver (e.g. Android emulators, some ISPs) fails a lookup even
though the record is published. A plain `Socket.connect(host, ...)` gives up at
the first `SocketException: Failed host lookup`.

How it works:

1. `DohResolver` queries public DoH endpoints (Cloudflare, Google) for A/AAAA
   records, caching with a short TTL and sharing one in-flight future per host.
2. `createDohAwareHttpClient()` installs an `HttpClient.connectionFactory` that
   resolves the host via DoH and connects to the returned IP directly.
   HTTPS connections are wrapped with `SecureSocket.secure(host: ...)`, so SNI
   and certificate validation still run against the real hostname — security is
   not bypassed.
3. If DoH is unreachable or returns nothing, the client falls back to the
   platform resolver (identical behavior to a plain `HttpClient`).

All outbound HTTP paths use this client: provider sources (`StalkerPortalClient`,
`XtreamMediaSource`), playlist/EPG downloads (`M3UDownloadService`,
`XMLTVDownloadService`), and stream probing (`DartHttpProbe`). A transient DNS
failure is retried through DoH on the next attempt instead of surfacing
immediately to the user.

---

### Stream Engine

The single source of truth for preparing all playback and download sessions.

Every media item passes through the same provider-independent pipeline:

```
Media Item
  ↓
Provider Config (ProviderConfigProvider)
  ↓
SessionManager.getOrCreateSession()
  ↓
ProviderSessionFactory (per provider type)
  ↓
ProviderSession (authenticated, provider-specific context)
  ↓
StreamResolver.resolve()
  ↓
AuthenticationEngine.applyAuthenticationToUrl()
  ↓
UrlNormalizer.canonicalize()
  ↓
CookieManager + HeaderEngine (headers, cookies, bearer)
  ↓
PlayableSessionFactory.create()
  ↓
StreamValidator.validate()
  ↓
PlayableSession → Playback Engine / Download Engine
```

**Invariant:** the Playback Engine and the Download Engine only ever receive
`PlayableSession` objects. No provider URL, provider model, or provider header
set ever reaches the player directly.

Responsibilities:

- Create, reuse, refresh, and persist provider sessions (`SessionManager`)
- Resolve raw source URLs into `StreamResolution`s (`StreamResolver`)
- Apply provider authentication (token refresh, URL signing, portal tokens)
- Attach headers, cookies, user agent, referer, origin, and bearer tokens
- Normalize and sanitize stream URLs (`UrlNormalizer`)
- Validate streams before playback/download (`StreamValidator`)
- Cache playable sessions (`StreamCache`) and encrypted provider sessions
  (`SessionCache` → Hive)
- Track stream health (`StreamHealthMonitor`)
- Fail over to backup URLs (`FailoverManager`)
- Prepare authenticated downloads (`DownloadPreparationService`)
- Publish stream lifecycle events (`StreamEventBus`)
- Run background session refresh tasks (`StreamTaskManager`)

#### ProviderSession

The authenticated, provider-specific context required to request streams from a
single IPTV provider. Produced by a `ProviderSessionFactory` registered for the
provider's `MediaSourceType`.

Fields:

- providerId, providerType, sessionId
- cookies, headers, bearerToken, macAddress, deviceId, portalToken
- username, password, expiresAt
- userAgent, referer, origin
- timeout, retryPolicy, capabilities, baseUrl

Every provider type has a factory:

- `M3UProviderSessionFactory`
- `XtreamProviderSessionFactory`
- `StalkerProviderSessionFactory`
- `BearerServerProviderSessionFactory` (Plex / Jellyfin / Emby)

#### PlayableSession

The single object understood by the Playback Engine and the Download Engine.

Fields:

- sessionId, mediaItemId, providerId, providerType
- streamUrl, streamType, mimeType
- headers, cookies, queryParameters, bearerToken, referer, origin, userAgent
- expiresAt
- capabilities (seeking, pause, recording, download, catchup, timeshift,
  subtitles, audio tracks)
- drmInformation
- networkTimeout, retryPolicy, metadata

Sensitive fields are never logged; `SensitiveDataRedactor` scrubs tokens,
cookies, credentials, and MAC addresses from all log output.

#### Session Lifecycle

1. `getOrCreateSession` loads the cached session or builds one through the
   provider factory.
2. `AuthenticationEngine.ensureValidSession` validates the session, refreshing
   it when expired, unauthenticated, or rejected by a quick check.
3. Valid sessions are persisted (encrypted) through `SessionCache`.
4. Sessions are invalidated on logout or provider removal.

#### Session Storage

Hive box `provider_sessions` (typeId 20) stores encrypted `ProviderSession`
data. Tokens, cookies, and credentials are encrypted before touching disk.

---

### IPTV Core

The provider-independent analysis and negotiation layer between the Stream
Engine and the Playback Engine. It transforms provider media into playable,
diagnosable streams without ever touching a provider or a player directly.

The IPTV Core is exposed through the `IptvCore` facade (`lib/core/iptv`),
constructed by `IptvCoreBinding` with a real `StreamEngine`, `StreamValidator`,
and `LoggingService`.

Pipeline:

```
Provider Input (URL / content)
  ↓
ProviderDetector        → ProviderDetectionResult (kind, transport, compression)
  ↓
ProviderCapabilityAnalyzer → ProviderCapabilities
  ↓
PlaylistAnalyzer        → PlaylistAnalysis (M3U classification, stats, headers)
  ↓
StreamEngine            → PlayableSession (existing pipeline)
  ↓
StreamNegotiationEngine → NegotiatedStream (protocol, player, capabilities)
  ↓
StreamAnalyzer          → StreamAnalysis (codec, resolution, DRM, variants)
  ↓
StreamDiagnosticsBuilder → StreamDiagnosticsReport
```

Subsystems:

- **Detection** — `ProviderDetector` (evidence-based provider kind detection:
  M3U, Xtream, Stalker, XMLTV, local; HTTP/HTTPS/file/inline transport; ZIP/GZIP
  compression), `ProviderCapabilityAnalyzer` (normalized capability set).
- **Playlist Analysis** — `PlaylistAnalyzer` classifies M3U entries into
  channels/movies/series/radio, extracts header attributes (EPG URLs, user
  agent, referer, custom headers), and computes protocol distribution.
- **Negotiation** — `StreamNegotiationEngine` runs protocol detection →
  capability detection → player negotiation → header negotiation → stream
  analysis, producing a single `NegotiatedStream`.
  - `ProtocolDetector` (`StreamProtocol`: HLS, DASH, MPEG-TS, MP4, MKV, RTSP,
    RTMP/S, UDP/RTP, HTTP/S)
  - `CapabilityDetector` (`StreamCapabilities`)
  - `PlayerNegotiator` (`PlayerNegotiation`: preferred engine, support level,
    fallbacks) — architecture only, never instantiates players
  - `HeaderNegotiator` (auth headers, cookies, UA, referer, origin)
- **Analysis** — `StreamAnalyzer` fetches bounded HLS/DASH manifests and derives
  codec, container, resolution, bitrate, DRM, and adaptive variants.
- **Diagnostics** — `StreamDiagnosticsBuilder` assembles a
  `StreamDiagnosticsReport` (steps, errors, warnings, root cause, timings) so
  every playback failure is traceable to a stage.
- **Recovery** — `ErrorRecoveryEngine` converts failures into actionable
  `RecoveryResult` categories (auth, network, protocol, retry, media, abort).
- **Debug Mode** — `DebugModeService` (reactive `DebugConfig`, per-category
  toggles), `DebugSessionLog` (bounded, chronological trace of a session).
- **Test Tools** — internal-only tools used by the Developer module:
  - `PlaybackTestTool` (resolve → validate → negotiate a URL)
  - `ProviderTestTool` (detect + capabilities + playlist analysis)
  - `StreamTestTool` (run a stored media item through the full pipeline)

**Invariant:** the UI and player never receive provider models or raw provider
URLs. The Negotiation output (`NegotiatedStream`) and `PlayableSession` are the
only stream representations that cross subsystem boundaries.

---

### Playback Engine

The playback engine is the heart of media consumption.

Responsibilities:

- Create playback sessions
- Manage playback state
- Resume / Stop / Pause / Seek / Change streams
- Buffer monitoring
- Quality management
- Playback analytics
- Error recovery

The engine is completely decoupled from provider implementations.

The player only understands `MediaItem` and `PlayableMediaSession`, and always
consumes streams through the `StreamEngine`, which produces `PlayableSession`
objects. The player never receives a raw provider URL or provider headers.

Future providers require zero player changes.

---

### Player Adapter

Every player implementation must implement `PlayerAdapter`.

Methods:

- kind
- isInitialized
- buildPlayerWidget()
- initialize()
- dispose()
- load()
- play()
- pause()
- resume()
- stop()
- seek()
- next()
- previous()
- setSpeed()
- setAspectRatio()
- setQuality()
- setAudioTrack()
- setSubtitleTrack()
- setVolume()
- getBufferInfo()

Implemented backends:

- MediaKitPlayerAdapter
- VlcPlayerAdapter (Android/iOS only)

Future backends may implement the same contract without any player-page or
business-logic changes: AVPlayer, ExoPlayer, Web Player.

---

### Playback Engine Selection

The `PlaybackEngine` owns backend selection; the UI never chooses a player.

Modes:

- **Auto (default)** — the engine selects the backend per session using the
  `PlayerSelectionStrategy`, which considers the stream URL, protocol, media
  type (live vs VOD) and the persisted `PlayerSettings.preferredPlayer`. If a
  load fails and the preference is `auto`, the engine swaps to the alternate
  backend and retries once per session (`allowEngineFallback`).
- **Explicit** — a forced `PlaybackEngineKind` (or an injected `PlayerAdapter`,
  e.g. in tests) disables selection and fallback.

Policy (Auto mode):

- RTSP, RTMP, RTMPS, UDP, RTP always → VLC
- HLS, MPEG-TS, live HTTP/HTTPS relays → VLC
- DASH, MP4, MKV, progressive HTTP(S) → MediaKit
- VLC unavailable (non-Android/iOS) → MediaKit

The `PlayerNegotiator` (protocol-only) and the `PlayerSelectionStrategy`
(protocol + media type + preference) must stay consistent.

`PlayerAdapterFactory.create()` is the only place that maps an engine kind to a
concrete adapter.

---

### Playback Session

Represents an active playback instance.

Fields:

- MediaItem
- PlayableStream
- Provider
- Resume Position
- Available Audio Tracks
- Subtitle Tracks
- Playback Capabilities
- Session Metadata

---

### Playback States

Enum:

- Idle
- Loading
- Buffering
- Playing
- Paused
- Stopped
- Completed
- Seeking
- Error
- Disposed

---

### Metadata Engine

The heart of metadata enrichment.

Responsibilities:

- Collect metadata from all providers
- Merge metadata into canonical items
- Resolve conflicts
- Normalize data
- Update Media Catalog
- Track metadata sources

Supported metadata sources:

- XMLTV
- TMDB
- TVMaze
- IMDb
- Trakt
- Fanart.tv
- Provider-native metadata
- Local metadata
- Custom metadata

---

### Metadata Providers

Every metadata source implements `MetadataProvider`.

Methods:

- initialize()
- refresh()
- search()
- lookup()
- enrich()
- validate()
- dispose()

Metadata providers behave exactly like media sources: they enrich the catalog but never dictate the UI.

Future metadata providers can be added without modifying the UI.

---

### Merge Engine

Responsibilities:

- Merge duplicate media across providers
- Resolve artwork
- Merge cast and crew
- Merge genres
- Merge ratings
- Merge descriptions
- Track conflicts

Configurable conflict resolution strategies:

- Highest quality
- Newest metadata
- Preferred provider
- Manual priority
- First available

---

### Search Index

Fast full-text search index.

Indexed fields:

- Title
- Alternate title
- Description
- Genres
- Cast
- Crew
- Language
- Country
- Provider
- Category
- Programs
- Episodes

---

### Media Index

Fast lookup structures.

By:

- ID
- Title
- Provider
- Category
- Genre
- Language
- Type

---

## Data Flow

```
User taps Channel

↓

Controller

↓

Repository / MediaEngine

↓

StreamEngine.resolvePlayback()

↓

ProviderSession → Resolver → Authentication → Headers → Cookies →

↓

URL Normalization → Validation → PlayableSession

↓

PlaybackEngine.playFromStreamEngine()

↓

PlayerAdapter.playSession(PlayableSession)

↓

Player
```

---

## Local Storage

Hive stores:

- Settings
- Media Sources
- Favorites
- History
- Downloads
- Watch Progress
- Cache Info
- Provider Sessions (encrypted via `SessionCache`, box `provider_sessions`)

SQLite may be used later for:

- Full-text search
- Large EPG datasets
- Complex indexing

---

## Cloud

Firebase stores:

- User Account
- Favorites
- Settings
- Watch History

Cloud sync should never block app startup.

---

## Project Structure

lib/

    core/

        config/

        constants/

        theme/

        routes/

        utils/

        network/

            doh_http_client.dart

        services/

        localization/

        errors/

        logging/

        bindings/

        media/

            enums/

            events/

            media_source.dart

            media_source_registry.dart

            media_source_manager.dart

            media_source_factory.dart

            media_engine.dart

            media_catalog.dart

            media_library.dart

            stream_resolver.dart

        streaming/

            stream_engine.dart

            models/

            errors/

            events/

            security/

            network/

            auth/

                providers/

            resolver/

            series/

                xtream_series_info_service.dart

            validation/

            health/

            cache/

            factory/

            failover/

            download/

            background/

            session/

                factories/

            repositories/

            controllers/

        iptv/

            iptv_core.dart

            models/

            detection/

            playlist/

            negotiation/

            analysis/

            recovery/

            debug/

            tools/

    data/

        models/

            media_item.dart

            media_metadata.dart

            playable_stream.dart

            channel.dart

            movie.dart

            series.dart

            episode.dart

            program.dart

            media_health.dart

            media_statistics.dart

            media_sync_result.dart

            m3u_models.dart

            canonical_media_item.dart

            metadata_models.dart

        repositories/

            media_repository.dart

            media_source_repository.dart

            catalog_repository.dart

            media_library_repository.dart

            media_repository_impl.dart

            media_source_repository_impl.dart

            catalog_repository_impl.dart

        services/

            cache_service.dart

            event_service.dart

            sync_service.dart

            provider_storage_service.dart

            catalog_service.dart

            filter_service.dart

            sort_service.dart

            source_service.dart

            metadata_service.dart

            health_service.dart

            profile_service.dart

            firebase_service.dart

            settings_service.dart

            search_service.dart

            database_service.dart

            merge_service.dart

            history_service.dart

            favorite_service.dart

            recommendation_service.dart

            m3u_download_service.dart

            playlist_cache_service.dart

            playlist_validation_service.dart

            playlist_statistics_service.dart

        metadata/

            metadata_engine.dart

            metadata_merge_engine.dart

            artwork_service.dart

            collection_engine.dart

            media_library_impl.dart

        indexes/

            search_index.dart

            search_engine.dart

            media_index.dart

        providers/

            iptv_provider_interface.dart

            metadata/

                metadata_provider.dart

                xmltv_metadata_provider.dart

                tmdb_metadata_provider.dart

                tvmaze_metadata_provider.dart

                imdb_metadata_provider.dart

                trakt_metadata_provider.dart

                fanart_metadata_provider.dart

                provider_native_metadata_provider.dart

                local_metadata_provider.dart

                custom_metadata_provider.dart

            m3u/

                m3u_media_source.dart

                m3u_content_classifier.dart

            stalker/

                stalker_portal_client.dart

                stalker_media_source.dart

            xtream/

                xtream_media_source.dart

                xtream_url_detector.dart

            stubs/

                m3u_source.dart

                custom_source.dart

                emby_source.dart

                future_source.dart

                hd_home_run_source.dart

                jellyfin_source.dart

                local_playlist_source.dart

                plex_source.dart

                tvheadend_source.dart

                xmltv_source.dart

        parsers/

            placeholder_parser.dart

            m3u_parser.dart

        local/

        remote/

    modules/

        splash/

        authentication/

        provider_manager/

        dashboard/

        live_tv/

        movies/

        series/

        search/

        player/

            bindings/

            controllers/

            pages/

            widgets/

        downloads/

        settings/

        developer/

            pages/

            widgets/

        profiles/

        favorites/

        history/

        epg/

    shared/

        widgets/

        dialogs/

        animations/

        extensions/

    database/

    generated/

---

## Series Experience Subsystem

The Series Experience provides a complete TV series tracking and playback ecosystem:

```
Series Hub / Details / Continue Watching
  ↓
NextEpisodeResolver / SeriesProgressService / IntroService
  ↓
Episode Selection & Playlist Injection (PlayerController)
  ↓
StreamEngine (Resolve PlayableSession)
  ↓
PlaybackEngine (Autoplay Next Overlay / Skip Intro Button)
```

### Components

1. **`NextEpisodeResolver`**:
   - Deterministic chronological traversal across episodes and season boundaries.
   - Handles multi-season ordering, non-contiguous episode numbering, and final episode completion.
2. **`SeriesProgressService`**:
   - Calculates aggregate series progress percentage and completed episode counts.
   - Determines dynamic watch action states: `playFirst`, `resume`, `playNext`, `watchAgain`.
3. **`IntroService`**:
   - Extracts intro start/end timestamps from episode metadata.
   - Provides segment caching and active playback position containment checks.
4. **`NextEpisodeOverlay` & `SkipIntroButton`**:
   - Non-intrusive floating overlays in `FullscreenPlayerPage`.
   - 10-second countdown with auto-transition at >92% completion / 15s remaining.
   - Instant seek to intro conclusion.

---

## Architecture Rules

- Keep widgets small.
- Controllers never call APIs.
- Use repositories.
- Reuse components.
- Prefer composition.
- One controller per module.
- Services contain business logic.
- Repositories communicate with services only.
- UI never knows provider types.
- Media sources are replaceable adapters.
- Everything is interface-based.
- All playback and downloads go through the Stream Engine.
- Players and download engines only receive `PlayableSession` objects.
- Stream URLs, tokens, cookies, and credentials are never logged.

