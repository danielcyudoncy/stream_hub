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
- Categories

Optional

- XMLTV Guide

### Supported Tags

- `#EXTM3U` — Playlist header
- `#EXTINF` — Channel metadata
- `tvg-id` — XMLTV channel ID
- `tvg-name` — Channel display name
- `tvg-logo` — Logo URL
- `group-title` — Category / group
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

The Stalker (MAG/STB middleware) portal is accessed over HTTP POST to its
load script. The script path is auto-detected in order: `/server/load.php`,
`/stalker_portal/server/load.php`, `/portal.php`. Requests are sent as
`application/x-www-form-urlencoded` with `JsHttpRequest=1-xml`, so responses
are wrapped in a `js` envelope.

Every request includes:

- `type=stb`
- `action=<action>`
- `token=<portal token>` (empty during the initial handshake)
- `Mac=<AA:BB:CC:DD:EE:FF>` (normalized to uppercase, colon-separated)
- `sn=<serial or MAC>`

### Actions

| Action | Purpose |
| ------ | ------- |
| `handshake` | Exchanges the MAC for a short-lived portal token (`js.token`, `js.serial`). |
| `get_profile` | Subscriber profile; `auth_status == 1` confirms the MAC is accepted. |
| `get_categories` | Category list for `type=live`, `type=vod`, or `type=series`. |
| `get_ordered_list` | Live TV channels for `type=live`. |
| `get_vod_categories` / `get_vod_list` | VOD categories and movies. |
| `get_series_categories` / `get_series_list` | Series list; each show embeds `seasons[]` with `episodes[]`. |
| `create_link` | Turns a stored `cmd` (plus `type`, `genre`) into a short-lived playable URL. |

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
