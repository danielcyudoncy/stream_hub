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

## Phase 3

Live TV

- Categories
- Channels
- Favorites
- Search
- Recently Watched

---

## Phase 4

Player

- Play Streams
- Resume
- PiP
- Audio Tracks
- Subtitles

---

## Phase 5

Movies & Series

- Movie Library
- TV Shows
- Continue Watching
- Metadata

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

- MAC Login
- Categories
- Channels
- Movies
- Series

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
