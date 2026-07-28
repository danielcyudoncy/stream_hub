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

Returns

- Channels
- Categories

Optional

- XMLTV Guide

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
