# API Providers

Every media source must expose the same data.

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
- Series
- Categories
- EPG

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
