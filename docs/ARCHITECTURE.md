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

        repositories/

        services/

        providers/

            stubs/

        local/

        remote/

        parsers/

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
