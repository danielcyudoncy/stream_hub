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

Returns

- TV Guide
- Program Schedule

---

## Local Playlist

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
