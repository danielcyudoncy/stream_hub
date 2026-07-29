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

Exposes:

- Live TV
- Movies
- Series
- Favorites
- Downloads
- History
- Recent
- Recommended
- Search
- Collections

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

---

## Data Flow

```
User taps Channel

↓

Controller

↓

Repository / MediaEngine

↓

MediaSource (adapter)

↓

Stream URL

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

        repositories/

            media_repository.dart

            media_source_repository.dart

            catalog_repository.dart

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

            m3u_download_service.dart

            playlist_cache_service.dart

            playlist_validation_service.dart

            playlist_statistics_service.dart

        providers/

            iptv_provider_interface.dart

            m3u/

                m3u_media_source.dart

            stubs/

                m3u_source.dart

                custom_source.dart

                emby_source.dart

                future_source.dart

                hd_home_run_source.dart

                jellyfin_source.dart

                local_playlist_source.dart

                plex_source.dart

                stalker_source.dart

                tvheadend_source.dart

                xmltv_source.dart

                xtream_source.dart

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

        downloads/

        settings/

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
