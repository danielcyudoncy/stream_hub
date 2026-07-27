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

Example:

HomeController

PlayerController

SearchController

---

### Repositories

Repositories are the bridge between controllers and services.

Responsibilities:

- Fetch data
- Cache data
- Decide local vs remote source

---

### Services

Services perform actual work.

Examples:

- M3U parsing
- Xtream API
- Stalker API
- XMLTV parsing
- Player
- Downloads

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

Channel

Movie

Series

Category

EPG

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

- Playlists
- Favorites
- History
- Settings
- Profiles
- Watch Progress

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

data/

modules/

shared/

database/

services/

---

## Architecture Rules

- Keep widgets small.
- Controllers never call APIs.
- Use repositories.
- Reuse components.
- Prefer composition.