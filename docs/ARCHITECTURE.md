# Architecture

## Overview

StreamHub Pro follows a simple layered architecture.

```
UI
 ↓
Controller (GetX)
 ↓
Repository
 ↓
Service
 ↓
Provider Adapter
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

---

### Controllers

Controllers:

- Manage screen state
- Call repositories
- Expose observable data
- Never call APIs directly

Examples:

- SettingsController
- ProviderManagerController
- ProfileController
- AuthController

---

### Repositories

Repositories are the bridge between controllers and services.

Responsibilities:

- Fetch data
- Cache data
- Decide local vs remote source

Examples:

- SettingsRepository
- ProviderRepository
- ProfileRepository
- AuthRepository

---

### Services

Services perform actual work.

Examples:

- SettingsService
- CacheService
- ProfileService
- ProviderStorageService
- DatabaseService

---

### Provider Adapters

Every IPTV source is treated as a provider.

Supported providers:

- M3U
- Xtream
- Stalker
- Local Playlist

Each provider returns the same models.

Example:

- ProviderModel
- Category
- Channel
- Movie
- Series
- EPG

---

## Data Flow

```
User taps Channel

↓

Controller

↓

Repository

↓

Provider

↓

Stream URL

↓

Player
```

---

## Local Storage

Hive stores:

- Settings
- Providers
- Profiles
- Favorites
- History
- Downloads
- Watch Progress
- Cache Info

SQLite may be used later for:

- Large EPG
- Search indexing

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

    data/

        models/

        repositories/

        services/

        local/

        remote/

        parsers/

        providers/

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