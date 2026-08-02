# IPTV Architecture Research

> **Purpose**
>
> This document records research and architectural observations from mature IPTV applications.
>
> It is **not** intended to copy or reverse engineer proprietary implementations.
> Instead, it identifies common design patterns, user experience ideas, and software architecture approaches that can inspire StreamHub Pro.
>
> Every architectural decision should prioritize modularity, maintainability, scalability, and provider independence.

---

# Goals

StreamHub Pro should become a premium cross-platform media platform rather than simply an IPTV player.

The application should:

- Support multiple provider types
- Support multiple playback engines
- Support multiple metadata providers
- Support multiple user workspaces
- Remain provider-independent
- Remain player-independent
- Be easily extensible

---

# High-Level Architecture

```
Providers
        │
        ▼
Media Sources
        │
        ▼
Media Engine
        │
        ▼
Metadata Engine
        │
        ▼
Media Library
        │
        ▼
Stream Engine
        │
        ▼
Playback Engine
        │
        ▼
Player Adapter
        │
        ▼
Native Player
```

---

# Research Areas

This document is organized into the following sections.

- Provider Systems
- Authentication
- Stream Resolution
- Playback
- Metadata
- EPG
- Search
- Downloads
- UI/UX
- Performance
- Architecture Decisions

---

# Provider Systems

## Supported Provider Types

Current target providers

- M3U
- Xtream Codes
- Stalker Portal
- XMLTV

Future providers

- Plex
- Jellyfin
- Emby
- Local Files
- SMB
- WebDAV
- DLNA

---

## Research Questions

- How are providers added?
- How are providers refreshed?
- How are providers authenticated?
- How are multiple providers merged?
- How are duplicate channels handled?
- How are provider priorities managed?

---

## StreamHub Decision

Providers must never communicate directly with the player.

Every provider must produce:

MediaItem

instead of

Provider-specific objects.

---

# Authentication

Possible authentication methods

- Username / Password
- Bearer Token
- Cookie
- MAC Address
- Portal Handshake
- API Key
- OAuth
- Anonymous

---

## Research Questions

- How are sessions refreshed?
- How are expired tokens handled?
- How are cookies stored?
- How are authentication failures recovered?

---

## StreamHub Decision

Authentication belongs inside the Stream Engine.

Never inside the player.

---

# Stream Engine

The Stream Engine prepares media for playback.

Responsibilities

- Resolve URLs
- Inject headers
- Manage cookies
- Normalize URLs
- Validate streams
- Manage sessions
- Retry failures
- Refresh authentication
- Prepare downloads

---

## Stream Pipeline

```
Media Item

↓

Provider Session

↓

Authentication

↓

Header Injection

↓

Cookie Injection

↓

URL Normalization

↓

Validation

↓

Playable Session

↓

Playback Engine
```

---

# Playable Session

The player should receive only one object.

```
PlayableSession
```

Example fields

- URL
- Headers
- Cookies
- User-Agent
- Referer
- Origin
- Expiration
- Stream Type
- MIME Type
- Metadata
- Capabilities

---

# Playback

Research

Which player engines are commonly used?

Examples

- VLC
- ExoPlayer
- AVPlayer
- MediaKit
- FFmpeg
- IJKPlayer

---

## Research Questions

Can different stream types use different players?

Can the application switch players automatically?

Can playback recover from failures?

---

## StreamHub Decision

Playback must use:

PlaybackEngine

↓

PlayerAdapter

↓

Native Player

Never directly call a player from UI.

---

# Metadata

Metadata providers

- XMLTV
- TMDB
- TVMaze
- IMDb
- Trakt
- Fanart.tv

---

## Research Questions

How is metadata merged?

How are duplicate items detected?

How are posters selected?

---

## StreamHub Decision

Metadata is provider-independent.

---

# Electronic Program Guide

Research

- XMLTV
- Native provider guides

---

Questions

- How is channel matching performed?
- How are updates synchronized?
- How are timelines cached?

---

# Search

Research

Should search include

- Channels
- Programs
- Movies
- Series
- Cast
- Genres
- Providers

---

Decision

Use one unified search engine.

---

# Downloads

Research

Can downloaded media reuse provider sessions?

Can expired URLs be refreshed?

Can interrupted downloads resume?

---

Decision

Downloads must use

PlayableSession

instead of

raw URLs.

---

# User Interface

Research

Modern streaming applications

Examples

- Apple TV
- Google TV
- Plex
- Jellyfin
- Netflix

---

Questions

How are dashboards organized?

How are empty states designed?

How are TV remotes supported?

How are desktop layouts adapted?

---

Decision

The dashboard should be media-focused.

Provider management belongs inside Settings.

---

# Performance

Research

- Playlist parsing
- XMLTV parsing
- Image caching
- Lazy loading
- Virtualized lists
- Background synchronization

---

# Workspaces

A Workspace represents an independent media environment.

Each Workspace owns

- Providers
- Favorites
- Watch History
- Continue Watching
- Downloads
- Search Index
- Recommendations
- Profiles

---

# Multi-Player Strategy

Possible future architecture

```
Playback Engine

↓

Player Selector

↓

MediaKit

↓

VLC

↓

AVPlayer

↓

ExoPlayer

↓

FFmpeg
```

The Playback Engine decides which player is most appropriate.

---

# Architecture Decisions

## Provider Independence

Providers never communicate with UI.

---

## Player Independence

Players never communicate with providers.

---

## Metadata Independence

Metadata providers enrich MediaItems.

---

## Unified Media Library

The UI always consumes the Media Library.

Never provider data.

---

## Unified Search

Search indexes MediaItems.

Never provider-specific objects.

---

## Stream Engine

All playback and downloads must use PlayableSession.

Never raw URLs.

---

# Applications to Evaluate

Current research list

- IPTV Streamer Max
- IPTV Extreme
- TiviMate
- Sparkle TV
- Televizo
- VLC
- Kodi
- Plex
- Jellyfin
- Emby

---

# Research Log

## IPTV Extreme

Status

Research in progress.

Observations

- Uses native multimedia libraries.
- Appears to support multiple playback technologies.
- Supports M3U and XMLTV.
- Supports advanced playback configuration.

Questions

- How are provider sessions managed?
- How are playback engines selected?
- How are headers injected?
- How are downloads authenticated?

---

## IPTV Streamer Max

Status

Pending

---

## TiviMate

Status

Pending

---

## Sparkle TV

Status

Pending

---

## Future Improvements

Potential future research

- Adaptive player selection
- Automatic stream failover
- Background stream health monitoring
- AI-assisted recommendations
- Automatic metadata enrichment
- Smart provider prioritization
- Predictive buffering
- Offline synchronization

---

# Guiding Principle

StreamHub Pro should never be tightly coupled to:

- A provider
- A player
- A metadata source
- A platform

Everything should communicate through well-defined interfaces.

The application should remain modular, extensible, and easy to maintain as new providers, playback technologies, and features are added.