# API Providers

Every media source must expose the same data.

---

## Stream Engine

All playback and downloads flow through the Stream Engine, which produces
authenticated, validated `PlayableSession` objects. The Playback Engine and the
Download Engine never receive raw provider URLs, provider models, or provider
headers.

### Pipeline

```
Media Item
  → ProviderConfigProvider (optional credentials/headers lookup)
  → SessionManager.getOrCreateSession()
  → ProviderSessionFactory (M3U / Xtream / Stalker / Bearer server)
  → ProviderSession
  → StreamResolver.resolve()
  → AuthenticationEngine.applyAuthenticationToUrl()
  → UrlNormalizer.canonicalize()
  → CookieManager + HeaderEngine
  → PlayableSessionFactory.create()
  → StreamValidator.validate()
  → PlayableSession
```

### Public API

`StreamEngine`:

- `resolvePlayback(...)` — resolve a media item into a validated `PlayableSession`
- `resolveStream(...)` — resolve a raw URL against an existing `ProviderSession`
- `prepareDownload(...)` — produce a `PreparedDownload` for authenticated downloads
- `validateStream(session)` — probe and validate a session
- `selectWorkingStream(session)` — fail over to a working backup URL
- `healthFor(sessionId)` — current health snapshot
- `cachedSession(providerId, mediaItemId)` — retrieve a cached session
- `startBackgroundTasks()` / `stopBackgroundTasks()` / `dispose()`

### Provider Session

Every provider type registers a `ProviderSessionFactory`:

| Provider type | Factory |
| --- | --- |
| M3U | `M3UProviderSessionFactory` |
| Xtream | `XtreamProviderSessionFactory` |
| Stalker | `StalkerProviderSessionFactory` |
| Plex / Jellyfin / Emby | `BearerServerProviderSessionFactory` |

Sessions carry cookies, headers, tokens, credentials, expiry, user agent,
referer, origin, timeout, retry policy, capabilities, and the provider base URL.
Sensitive fields are encrypted before persistence (Hive box `provider_sessions`)
and are never logged.

### Session Lifecycle

1. `getOrCreateSession` reuses a cached session or builds one via the factory.
2. `AuthenticationEngine.ensureValidSession` validates the session and refreshes
   it when expired, unauthenticated, or rejected.
3. Sessions are persisted encrypted and invalidated on logout/provider removal.

### Authentication

Each provider registers an `AuthenticationProvider`:

- `M3UAuthenticationProvider`
- `XtreamAuthenticationProvider`
- `StalkerAuthenticationProvider`
- `BearerTokenAuthenticationProvider`

A provider advertises `supportsRefresh`; the engine refreshes before failing.

### Stream Resolution

`StreamResolver` implementations resolve provider URLs into `StreamResolution`s:

- `DefaultStreamResolver` — relative URL resolution, redirect following with loop
  detection, stream-type/mime detection, quality/capability detection, DRM
  discovery, backup URL collection, expiration detection
- Provider-specific resolvers may extend or replace it

### Validation

`StreamValidator` performs:

- URL syntax and scheme checks
- Expiry checks
- Header integrity (no header injection)
- HTTP(S) reachability probes (content-type, status code, redirects)

Supported schemes: `http`, `https`, `rtsp`, `rtmp`, `rtmps`, `mms`.

### Failover

`FailoverManager` selects a working candidate from primary + backup URLs. The
player only ever sees a single valid `PlayableSession`.

### Downloads

`DownloadPreparationService` produces `PreparedDownload` objects with suggested
file names and extensions. Downloads reuse the exact cookies/headers of playback.

### Events

Stream events (session created/refreshed/expired, authentication failed, stream
resolved, playback ready, download ready, health updated) are published on a
shared `StreamEventBus`.

---

## IPTV Core

The provider-independent analysis and negotiation layer between the Stream
Engine and the Playback Engine. Exposed through the `IptvCore` facade
(`lib/core/iptv`), constructed by `IptvCoreBinding`.

### Provider Detection

`ProviderDetector.detect(ProviderInput)` returns a `ProviderDetectionResult`:

| Field | Description |
| --- | --- |
| `providerKind` | M3U / Xtream / Stalker / XMLTV / local / unknown |
| `transportKind` | Remote HTTP / Remote HTTPS / Local File / Inline Content |
| `compressionKind` | none / ZIP / GZIP |
| `confidence` | 0.0 – 1.0 |
| `matchedSignals` | evidence that drove the decision |

Input is a URL and/or content sample. Detection is evidence-based; every matched
signal is recorded for diagnostics.

### Provider Capabilities

`ProviderCapabilityAnalyzer.analyze(detection, {config})` returns a normalized
`ProviderCapabilities` object. The UI and negotiation layer respond to these
capabilities, never to provider types.

Capabilities include: `supportsLiveTv`, `supportsMovies`, `supportsSeries`,
`supportsRadio`, `supportsCatchup`, `supportsTimeshift`, `supportsEpg`,
`supportsDownloads`, `supportsStreamResolution`, `supportsPlaylistRefresh`,
`supportsBackupStreams`, `supportsCustomHeaders`, `requiresCredentials`,
`supportsAnonymousAccess`, `supportedProtocols`.

Config keys `catchup`/`catchupSupported`, `timeshift`/`timeshiftSupported`, and
`customHeaders`/`supportsHeaders` can override the defaults.

### Playlist Analysis

`PlaylistAnalyzer.analyze(content, {sourceUrl, providerKind})` returns a
`PlaylistAnalysis`:

- Entry classification (channels, movies, series, radio counts)
- Groups, TVG info, EPG sources (`x-tvg-url`, `url-tvg`, ...)
- Header extraction (user agent, referer, origin, custom headers)
- Catch-up / timeshift detection
- `PlaylistStats` (total/valid/invalid entries, duplicates, encoding, duration)
- Protocol distribution (`hls`, `mpegts`, `mp4`, `mkv`, `dash`, ...)
- Errors and warnings for diagnostics

### Stream Negotiation

`StreamNegotiationEngine.negotiate({session, providerSession, probe, withAnalysis})`
turns a resolved `PlayableSession` into a `NegotiatedStream`:

```
Protocol Detection → Capability Detection → Player Negotiation
→ Header Negotiation → Stream Analysis → NegotiatedStream
```

`NegotiatedStream` carries: `protocol` (`StreamProtocol`), `streamType`,
`playerNegotiation` (engine, support level, fallbacks), `capabilities`, headers,
cookies, user agent, referer, origin, fallback URLs, `analysis`, expiry, metadata.

`PlayerNegotiation` selects an engine family (MediaKit / AVPlayer / ExoPlayer /
VLC / fallback) with a support level (native / supported / degraded /
unsupported). It is architecture-only and never instantiates players.

### Stream Analysis

`StreamAnalyzer.analyze(session, {probe, fetchManifest})` fetches bounded
HLS/DASH manifests and derives codec, container, resolution, frame rate,
bitrate, audio, language, DRM (`drmScheme`), variant count, and max bandwidth.

### Diagnostics

`StreamDiagnosticsBuilder.build(...)` assembles a `StreamDiagnosticsReport`:

- `steps` — per-stage trace (`DiagnosticStep`)
- `errors` / `warnings`
- `rootCause` — best-effort failure category (Authentication, Headers, URL,
  Timeout, Protocol, Player, Provider, Network)
- `totalDuration`, `startedAt`, `completedAt`, `succeeded`

### Error Recovery

`ErrorRecoveryEngine.recover(...)` converts failures into `RecoveryResult`
categories: `auth`, `network`, `protocol`, `media`, `retry`, `abort`.

### Debug Mode

`DebugModeService` exposes a reactive `DebugConfig` with per-category toggles
(verbose, http, headers, session, timing, player events). `DebugSessionLog`
records a bounded chronological trace of a session for diagnostics.

### Developer Test Tools

Internal-only tools consumed by the Developer module:

| Tool | Purpose |
| --- | --- |
| `PlaybackTestTool.testUrl(url)` | detect → resolve → validate → negotiate, returns `PlaybackTestResult` |
| `ProviderTestTool.analyze({url, content})` | detection + capabilities + playlist analysis |
| `StreamTestTool.testItem(...)` | run a stored media item through the full pipeline |

### Developer Module

`/developer` (Settings → Developer → Developer Tools) hosts the debug-mode
toggle plus the Playback Test, Provider Test, and Stream Test screens.

---

## Common Models

All sources should return:

- Channels
- Movies
- Series
- Episodes
- Programs
- Categories

---

## Media Source Interface

Every source must implement:

- initialize()
- connect()
- disconnect()
- dispose()
- refresh()
- sync()
- validate()
- health()
- statistics()

This keeps the UI independent from source type.

---

## M3U

Input

- URL
- Local File
- Username/Password in URL
- Basic HTTP Authentication
- HTTPS
- HTTP

Returns

- Channels
- Movies
- Series
- Categories

Optional

- XMLTV Guide

### Content Classification

Entries are classified into live channels, movies and series by
`M3UContentClassifier` using these signals in priority order:

1. `tvg-type` EXTINF attribute (authoritative). `movie` / `vod` / `film*`
   classify as movies; `series` / `tvshow` / `show` classify as series;
   `live` / `channel` / `tv` classify as live.
2. Stream URL path (e.g. `/movie/`, `/series/`, `/live/`).
3. `group-title` keywords (e.g. "Movies", "TV Series").

Classified movies and series are exposed through `getMovies()` / `getSeries()`
and the `moviesStream` / `seriesStream` controllers, so they flow into the
library and player like any other VOD provider.

### Xtream Export Detection

An M3U URL that points at an Xtream panel export (`get.php` or
`player_api.php` with `username` / `password` query parameters, optionally
schemeless) is not downloaded as a playlist. `XtreamUrlDetector` recognizes the
link and `M3UMediaSource` delegates the whole sync to `XtreamMediaSource`,
which uses the panel's JSON API. This mirrors mature IPTV apps and avoids
downloading exports that can be orders of magnitude larger than the API (and
that some servers refuse to serve in full).

The provider form applies the same detection: pasting an export link switches
the provider type to Xtream and prefills the username and password from the
URL.

### Supported Tags

- `#EXTM3U` — Playlist header
- `#EXTINF` — Channel metadata
- `tvg-id` — XMLTV channel ID
- `tvg-name` — Channel display name
- `tvg-logo` — Logo URL
- `group-title` — Category / group
- `tvg-type` — Content type (`live`, `movie`, `series`, ...)
- `radio` — Radio station flag
- `catchup` — Catch-up support flag
- `catchup-days` — Catch-up availability window
- `catchup-source` — Catch-up stream URL template
- `audio-track` — Audio track information
- `language` — Channel language
- `country` — Channel country

### Validation Rules

- Missing `#EXTM3U` header triggers a warning, not a failure
- Entries without a preceding `#EXTINF` line are flagged as malformed
- Duplicate stream URLs are detected and counted
- Empty channel names generate warnings
- UTF-8 encoding is assumed; invalid UTF-8 sequences produce decode errors
- Playlists with only whitespace or empty content are rejected

### Authentication

- Basic HTTP Authentication via `username` and `password` config fields
- Credentials embedded in URL (`http://user:pass@host/playlist.m3u`)
- Custom headers via `headers` map

### Caching

- Parsed playlists are cached locally with:
  - Raw playlist text
  - Parsed channel list
  - Validation result
  - Statistics
  - Timestamp
  - Content hash
  - ETag
  - Last-Modified

### Statistics

- Total items
- TV channels
- Radio stations
- Categories
- Languages
- Countries
- Invalid entries
- Duplicates
- Sync duration

---

## Xtream Codes

Input

- Server URL
- Username
- Password

Returns

- Live TV
- Movies
- Series
- Categories
- EPG

### Protocol

The Xtream Codes API is accessed over HTTP(S) **GET** to the panel
`player_api.php` endpoint. A schemeless server URL (e.g. `panel.example.com`)
is normalized to `http://` and trailing slashes are stripped. Every request
includes:

- `username=<username>`
- `password=<password>`
- `action=<action>`

Endpoints used by `XtreamMediaSource`:

| Action | Content |
|--------|---------|
| `live` | Live TV channels |
| `get_live_streams` | Live TV channels (fallback for panels without `live`) |
| `get_vod_streams` | VOD movies |
| `get_series` | Series |
| `get_live_categories` | Live TV categories |
| `get_vod_categories` | Movie categories |
| `get_series_categories` | Series categories |
| `get_series_info&series_id=<id>` | Season/episode structure (resolver) |

Some panels answer `action=live` with only `user_info` and no stream list. When
that happens, `XtreamMediaSource` retries with `action=get_live_streams` before
giving up on live channels.

List endpoints are parsed from both standard `{"data": [...]}` wrappers and
bare top-level arrays. Several real-world panels (e.g. those fronted by
Proxyschield) return a bare JSON array for every list endpoint while still
returning the `user_info` object for an unauthenticated request.

A bare request with no `action` returns `user_info` (used by `validate()`; a
successful session reports `user_info.auth == 1`). During sync the source also
reads `created_at`, `exp_date`, `status`, `is_trial`, and `max_connections`
from `user_info` into an `AccountMetadata` model, which the provider manager
persists and shows on the provider details page (real account creation date,
expiry date — `exp_date: 0` renders as "Never" — trial flag, and connection
limit).

Panel quirk: optional string fields such as `backdrop_path` may be emitted as
empty lists (or other non-string JSON values). The source extracts string
metadata through a tolerant helper (`_asString`) that nulls empty lists/maps and
stringifies scalar values instead of crashing the whole sync.

Items are normalized into `MediaItem`s. Live and movie items carry an
authenticated `streamUrl` so they play directly; series items carry only a
`seriesId` (plus the `streamId`). Stream URL shapes:

- Live: `{server}/live/{user}/{pass}/{streamId}.{ext}`
- Movie: `{server}/movie/{user}/{pass}/{streamId}.{ext}`
- Series episode: `{server}/series/{user}/{pass}/{episodeId}.{ext}`

The `XtreamStreamResolver` plays live/VOD items directly and resolves series by
querying `get_series_info`, handling both `seasons[].episodes[]` and
`episodes: {"1": [...]}` payload layouts. When `metadata['episodeId']` is
present (e.g. an episode chosen from the Series Details screen) that exact
episode is resolved; otherwise the first playable episode is used. Unsupported
schemes are rejected via `StreamUnsupportedProtocolException`.

Episode discovery is centralized in `XtreamSeriesInfoService`
(`core/streaming/series/`), which fetches and parses `get_series_info` and is
the shared source of truth for both the resolver (playback) and the Series
Details screen (browsing seasons/episodes). It builds the
`{server}/series/{user}/{pass}/{episodeId}.{ext}` URL for each episode.

Some panels do not implement `get_series_info` and answer HTTP 404. To cope:

- The service tries the `series_id` first, then any alternative IDs (the
  series' `stream_id`, which some panels index series info by); it also
  unwraps a `{"data": {...}}` payload wrapper.
- If every candidate 404s, it throws
  `StreamSeriesInfoUnavailableException` so the UI degrades gracefully.
- The Series Details controller falls back to episodes already persisted in the
  local catalog and otherwise shows a friendly "episodes unavailable" state
  (with retry) instead of a raw error. Stalker episodes (already persisted
  during sync) are read from the local catalog.

---

## Stalker Portal

Input

- Portal URL
- MAC Address

Optional

- Device ID
- Serial Number

Returns

- Live TV
- Movies
- Series (with episodes)
- Categories
- EPG (via XMLTV enrichment)

### Protocol

The Stalker (MAG/STB middleware) portal is accessed over HTTP **GET** to its
load script. The script path is auto-detected in order: `/server/load.php`,
`/stalker_portal/server/load.php`, `/portal.php`. Each absolute path candidate
is probed both at the web root (origin) and, when the portal URL contains a
subpath such as `/c/`, relative to that subpath — some deployments serve the
UI from `/c/` while the API lives at the root. A schemeless portal URL (e.g.
`portal.example.com/c`) is normalized to `http://` automatically. All
parameters are sent as query string fields with `JsHttpRequest=1-xml`, so
responses are wrapped in a `js` envelope.

GET is the only supported transport: many portal deployments reject POST
with a Cloudflare `444` / HTML block page or silently drop the body, so the
client never POSTs to the API.

Every request includes:

- `type=stb` (content actions use `type=itv` for live TV, `type=vod`, or
  `type=series`)
- `action=<action>`
- `token=<portal token>` (empty during the initial handshake)
- `Mac=<AA:BB:CC:DD:EE:FF>` (normalized to uppercase, colon-separated)
- `sn=<serial or MAC>`

Plus the mandatory `Cookie` header:

- `mac=<AA%3ABB%3ACC%3ADD%3AEE%3AFF>` (URL-encoded, required — the portal
  returns an empty body without it)
- `sn=<serial or MAC>`
- `stb_lang=en`
- `timezone=UTC`

Requests are sent with a STB-style User-Agent
(`Mozilla/5.0 (QtEmbedded; U; Linux; C) AppleWebKit/533.3 (KHTML, like Gecko)
MAG200 stbapp ver: 4.8.0`). When a token is present it is sent as a
`Bearer` Authorization header.

#### Rate Limiting

Portals throttle requests per source IP and commonly answer bursts with
`HTTP 429 Too Many Requests` (or an HTTP 200 with an **empty body** — a second,
harder-to-see throttle signature). The client handles both transparently:

- Requests are paced: at least `1200ms` elapses between two portal requests so
  catalog sync bursts stay under the ~1 req/s limiter.
- `429` (and transient `500/502/503/504`) responses are retried with
  exponential backoff (`800ms`, `1.6s`, `3.2s`, plus jitter), up to 3 times
  per request. A `Retry-After` header in the error body is honoured when
  present.
- Empty bodies are retried (up to 2 times) for data actions (`get_profile`,
  `get_ordered_list`, `get_vod_list`, `get_series_list`) and then tolerated.
  Category actions (`get_categories`) tolerate empty bodies immediately,
  because some portals simply do not implement them and always answer empty.
- `StalkerMediaSource` treats a persistent throttle/empty response as transient
  and re-runs the whole sync through its own backoff loop rather than failing
  immediately. A sync that loads zero media is also retried.

`StalkerPortalException.statusCode` carries the offending HTTP status and
`isEmptyResponse` marks an empty-body response, so callers can distinguish
transient (retryable) failures from permanent ones.

### Actions

| Action | Purpose |
| ------ | ------- |
| `handshake` | Exchanges the MAC for a short-lived portal token (`js.token`, `js.serial`). |
| `get_profile` | Subscriber profile; `auth_status == 1` confirms the MAC is accepted. |
| `get_categories` | Category list for `type=itv`, `type=vod`, or `type=series`. |
| `get_ordered_list` | Content list for `type=itv`, `type=vod`, or `type=series` (the API uses `itv`, not `live`). |
| `get_vod_categories` / `get_vod_list` | VOD categories and movies. |
| `get_series_categories` / `get_series_list` | Series list; each show embeds `seasons[]` with `episodes[]`. |
| `create_link` | Turns a stored `cmd` (plus `type`, `genre`) into a short-lived playable URL. |

Portals differ in how they expose VOD and series. `getVodList()` /
`getSeriesList()` try the dedicated actions (`get_vod_list` /
`get_series_list`) first and fall back to `get_ordered_list?type=vod|series`
when the dedicated action answers with an empty body, so both Ministra-style
and shared ordered-list deployments work.

### Stream Resolution

Playback is deferred to `create_link` at play time. The response provides
either a direct `js.url` or an `js.cmd` (`ffmpeg -i 'URL' ...`) from which the
stream URL is extracted. Items that expose a direct source (e.g.
`direct_source` in live channels) are played directly without the exchange.

### Components

- `StalkerPortalClient` — low-level portal HTTP client
  (`lib/data/providers/stalker/stalker_portal_client.dart`).
- `StalkerMediaSource` — `MediaSource` implementation performing handshake +
  catalog ingestion (`lib/data/providers/stalker/stalker_media_source.dart`).
- `StalkerStreamResolver` — `create_link`-based playback resolver
  (`lib/core/streaming/resolver/stalker_stream_resolver.dart`), routed through
  `CompositeStreamResolver`.
- `StalkerAuthenticationProvider` — token validation + real-handshake refresh
  (`lib/core/streaming/auth/providers/stalker_authentication_provider.dart`).
- `StalkerProviderSessionFactory` — builds the `ProviderSession`
  (`lib/core/streaming/session/factories/stalker_provider_session_factory.dart`).

---

## Metadata Providers

Metadata providers enrich existing media items with additional metadata
without changing the UI.

### MetadataProvider Interface

Every metadata provider must implement:

- initialize()
- refresh()
- search()
- lookup()
- enrich()
- validate()
- dispose()

### Supported Metadata Sources

- XMLTV
- TMDB
- TVMaze
- IMDb
- Trakt
- Fanart.tv
- Provider Native
- Local
- Custom

### Metadata Source Types

- xmltv
- tmdb
- tvmaze
- imdb
- trakt
- fanart
- provider
- local
- custom

---

## XMLTV

Input

- XML URL
- XML.GZ URL
- Local XML
- Local XML.GZ
- Large XML files
- Compressed guides

Returns

- TV Guide
- Program Schedule
- Channel Metadata
- Enriched Media Catalog

### Supported XMLTV Tags

- `channel` — Channel definition with `id` attribute
- `display-name` — Channel display name
- `icon` — Channel logo/icon URL via `src` attribute
- `programme` — Program entry with `start`, `stop`, `channel` attributes
- `title` — Program title
- `sub-title` — Program subtitle
- `desc` — Program description
- `category` — Program category/genre
- `language` — Programme language
- `country` — Programme country
- `episode-num` — Episode number with `system` attribute
- `date` — Programme date
- `rating` — Content rating with `value` child
- `star-rating` — Star rating with `value` child
- `credits` — Credits group with `director`, `actor`, `writer`, `producer`, `presenter`, `guest` children
- `new` — Flag for new programmes
- `premiere` — Flag for premiere programmes
- `last-chance` — Flag for last-chance programmes
- `previously-shown` — Flag for re-run programmes
- `video` — Video metadata (`aspect`, `quality`, `codec`, `resolution`)
- `audio` — Audio metadata (`stereo`, `codec`, `channels`)
- `subtitles` — Subtitle metadata (`language`, `format`)

### Channel Matching

XMLTV uses a fuzzy channel matching engine that matches XMLTV channels to existing channels using:

- `tvg-id` — Exact match on XMLTV channel ID
- `display-name` — Exact or fuzzy match on channel name
- `channel-id` — Match on internal channel identifier
- `normalized name` — Case-insensitive, punctuation-stripped comparison
- `aliases` — Match against known channel aliases

Fuzzy matching is supported for display-name comparisons.

### Download Service

The XMLTV download service supports:

- HTTP and HTTPS protocols
- Basic HTTP Authentication
- Custom headers
- GZip decompression (.xml.gz)
- Automatic encoding detection (UTF-8, UTF-16 LE/BE, BOM)
- Configurable timeout, retry count, and retry delay
- Redirect following with configurable max redirects
- Download cancellation via CancellationToken
- Download progress reporting

### Streaming Parser

The XMLTV parser uses a streaming XML reader for low memory usage:

- Processes XML incrementally without loading the full document
- Supports guides up to 500MB
- Handles malformed XML with recovery
- Supports UTF-8 and UTF-16 encodings
- Handles compressed (.gz) guides
- Gracefully skips unknown elements

### Metadata Enrichment

XMLTV enriches the Media Catalog by merging XMLTV metadata into existing channels and programmes:

1. Existing channels receive poster/icon URLs, language, country, and aliases from XMLTV
2. Existing programmes receive enriched metadata (ratings, cast, directors, categories)
3. New programmes from XMLTV are added to the catalog
4. The UI is unaware of the metadata source

### Caching

XMLTV guides are cached locally with:

- Parsed guide data (channels, programmes)
- Content hash for change detection
- Cache timestamp and expiry (24 hours TTL)
- Guide size and encoding info
- Guide version

### Statistics

- Total programmes
- Total channels
- Matched channels
- Unmatched channels
- Duplicate programmes
- Categories
- Languages
- Ratings
- Guide size
- Sync duration

### Health Monitoring

- Guide version
- Guide size
- Programme count
- Matched channel count
- Unmatched channel count
- Last refresh timestamp
- Errors and warnings

### Sync

- Manual sync trigger
- Background sync interface
- Incremental sync with change detection
- Guide merge with conflict resolution
- Changed channel detection
- New programme detection
- Expired programme detection

---

## Local Playlist

Input

- M3U File
- XML File

Returns

- Offline Channels
- Offline Guide

---

Input

- M3U File
- XML File

Returns

- Offline Channels
- Offline Guide

---

## Jellyfin

Input

- Server URL
- API Key

Returns

- Movies
- Series
- Episodes
- Categories

---

## Plex

Input

- Server URL
- Token

Returns

- Movies
- Series
- Episodes
- Categories

---

## Emby

Input

- Server URL
- API Key

Returns

- Movies
- Series
- Episodes
- Categories

---

## TVHeadend

Input

- Server URL
- Credentials

Returns

- Live TV
- Categories
- EPG

---

## HDHomeRun

Input

- Device IP
- Tuner configuration

Returns

- Live TV
- Channels

---

## Custom

Input

- Custom configuration provided by user

Returns

- Depends on adapter

---

## Future

Input

- Determined by implementation

Returns

- Depends on implementation

---

## Supported Source Types

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
