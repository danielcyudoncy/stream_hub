# API Providers

Every provider must expose the same data.

---

## Common Models

All providers should return:

- Categories
- Channels
- Movies
- Series
- EPG

---

# M3U

Input

- URL
- Local File

Returns

- Channels
- Categories

Optional

- XMLTV Guide

---

# Xtream Codes

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

# Stalker Portal

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

# XMLTV

Input

- XML URL
- XML.GZ URL
- Local XML

Returns

- TV Guide
- Program Schedule

---

# Local Playlist

Input

- M3U File
- XML File

Returns

- Offline Channels
- Offline Guide

---

# Future Providers

- Jellyfin
- Emby
- Plex
- TVHeadend
- HDHomeRun

---

# Provider Interface

Every provider should support:

- Login
- Refresh
- Get Categories
- Get Channels
- Get Movies
- Get Series
- Get EPG
- Get Stream URL

This keeps the UI independent from provider type.