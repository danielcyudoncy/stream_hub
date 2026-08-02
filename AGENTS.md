# AGENTS.md

## StreamHub Pro

**Project Type:** Commercial IPTV Player
**Framework:** Flutter
**Language:** Dart
**Architecture:** Clean Architecture + GetX
**State Management:** GetX
**Database:** Hive + SQLite
**Backend:** Firebase
**Platforms:**

- iOS
- Android
- Android TV
- Apple TV
- macOS
- Windows
- Linux (optional)

---

## Project Vision

StreamHub Pro is a premium IPTV player designed to support multiple IPTV
standards while delivering a modern, fast, and elegant experience.

The application DOES NOT provide IPTV content.

The application allows users to connect their own IPTV providers using supported
connection methods.

Supported provider types include:

- M3U URL
- M3U File
- Xtream Codes API
- Stalker Portal (MAC)
- XMLTV
- Custom APIs (future)

---

## Core Principles

The project should be:

- Modular
- Highly maintainable
- Feature scalable
- Testable
- Offline-first
- Fast
- Beautiful
- Cross-platform

Avoid tightly coupling business logic with UI.

Controllers should never directly perform network requests.

Use repositories and services.

---

## IPTV Provider Architecture

Providers MUST NEVER communicate directly with:

- UI
- Player
- Download Engine

Every provider must implement a common ProviderAdapter interface.

Providers only produce normalized media models.

The playback pipeline must remain provider-independent.

Pipeline

Provider

↓

Provider Adapter

↓

Media Engine

↓

Media Library

↓

Stream Engine

↓

Playback Engine

↓

Player Adapter

↓

Native Player

## IPTV Core

The IPTV Core is responsible for transforming provider media into playable media.

The IPTV Core includes:

- Provider Detection
- Playlist Analysis
- Provider Session Management
- Authentication
- Stream Resolution
- URL Normalization
- Header Injection
- Cookie Management
- Capability Detection
- Stream Validation
- Stream Negotiation

The IPTV Core must remain provider-independent.

All provider implementations eventually produce the same object:

PlayableSession

## Stream Engine

The Stream Engine is the only component allowed to prepare media for playback.

Responsibilities

- Resolve stream URLs
- Authenticate requests
- Inject HTTP headers
- Manage cookies
- Validate streams
- Handle redirects
- Handle retries
- Generate PlayableSession objects
- Prepare downloads
- Monitor stream health

The Player must never receive a raw provider URL.

## PlayableSession

The Player receives only a PlayableSession.

Never

- M3UChannel
- XtreamChannel
- StalkerChannel
- Raw URL

PlayableSession contains

- Stream URL
- Headers
- Cookies
- Authentication
- Metadata
- Stream Capabilities
- Session Information
- Timeout
- Retry Policy

## Capability System

Every playable stream exposes capabilities.

Examples

- Seek
- Pause
- Download
- Record
- Catch-up
- Timeshift
- PiP
- Chromecast
- AirPlay
- Subtitles
- Multiple Audio Tracks

The UI should respond to capabilities rather than provider types.

## Player Independence

The Playback Engine controls playback.

The UI never communicates directly with:

- MediaKit
- VLC
- ExoPlayer
- AVPlayer

All playback passes through

PlaybackEngine

↓

PlayerAdapter

↓

Native Player

This allows player implementations to be replaced without affecting business logic.

## Provider Independence

The application must never contain provider-specific UI.

The UI consumes only normalized models.

Examples

MediaItem

Channel

Movie

Series

Category

EpgProgram

PlayableSession

Never

XtreamMovie

XtreamChannel

M3UChannel

StalkerChannel

inside widgets.
---

## Folder Structure

lib/

    core/

        config/

        constants/

        theme/

        routes/

        utils/

        services/

    data/

        models/

        repositories/

        providers/

        parsers/

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

## State Management

Use GetX only.

Guidelines:

- One controller per module.
- Never put API logic inside widgets.
- Never put business logic inside UI.
- Controllers communicate with repositories.
- Repositories communicate with services.
- Services communicate with APIs.

---

## Dependency Injection

Use Get.put()

Use Get.lazyPut()

Avoid global singleton classes unless required.

---

## Local Storage

Hive is the primary database.

SQLite may be used for:

- Full-text search
- Large EPG datasets
- Complex indexing

Store locally:

- Playlists
- Channels
- Movies
- Series
- Favorites
- History
- Downloads
- Watch progress
- Profiles
- Hidden categories
- Settings

The application should remain functional while offline whenever possible.

---

## Cloud

Firebase is responsible for:

Authentication

Firestore

Cloud Storage

Crashlytics

Cloud Messaging

Remote Config (future)

Cloud sync should never block application startup.

Always prioritize local cache.

---

## IPTV Provider System

Every IPTV source must implement the same interface.

Example:

abstract class IPTVProvider {

Future<List<Category>> getCategories();

Future<List<Channel>> getChannels();

Future<List<Movie>> getMovies();

Future<List<Series>> getSeries();

Future<List<EpgProgram>> getEPG();

Future<String> getStreamUrl();

}

Supported implementations:

- M3U Provider
- Xtream Provider
- Stalker Provider
- Local Provider

Future providers can be added without changing UI code.

---

## UI Guidelines

Design language:

Modern

Minimal

Premium

Fast

Smooth animations

Avoid clutter.

Support:

Dark Theme

Light Theme

TV Layout

Desktop Layout

Mobile Layout

---

## Performance Rules

Lazy load everything.

Never load entire EPG into memory.

Cache posters.

Cache logos.

Cache categories.

Cache playlists.

Use pagination whenever possible.

Avoid unnecessary rebuilds.

Use GetBuilder or Obx appropriately.

---

## Player

Preferred player:

media_kit

Required features:

Resume playback

Picture-in-Picture

Hardware decoding

Subtitles

Audio tracks

Playback speed

Continue Watching

Mini Player

Future:

AirPlay

Chromecast

Multi-screen

---

## Coding Standards

Follow Effective Dart.

Files:

snake_case

Classes:

PascalCase

Variables:

camelCase

Constants:

camelCase prefixed with k when appropriate

Prefer immutable models.

Avoid dynamic types.

Always use null safety.

---

## Error Handling

Never silently fail.

Log all exceptions.

Provide user-friendly messages.

Retry network requests when appropriate.

Cache successful responses.

---

## Security

Never hardcode credentials.

Encrypt sensitive local data.

Store authentication securely.

Validate provider URLs.

Sanitize imported playlists.

---

## Testing

Write tests for:

Repositories

Services

Parsers

Controllers

Critical business logic

---

## Git Workflow

Feature branches:

feature/`feature-name`

Bug fixes:

fix/`bug-name`

Refactoring:

refactor/`module`

Documentation:

docs/`topic`

---

## Pull Requests

Every PR should:

Compile successfully

Pass tests

Contain documentation when needed

Avoid unrelated code changes

Remain focused on one feature

---

## Roadmap

Phase 1

- Project setup
- Theme
- Routing
- Authentication
- Provider Manager

Phase 2

- M3U Support
- Xtream Support
- XMLTV

Phase 3

- Live TV
- Player
- EPG

Phase 4

- Movies
- Series
- Continue Watching

Phase 5

- Stalker Portal
- Cloud Sync
- Downloads

Phase 6

- Chromecast
- AirPlay
- Multi-screen
- Desktop Optimization

Phase 7

- AI Recommendations
- Analytics
- Performance Optimization
- Premium Features

---

## 📚 Project Documentation

Before making changes to this project, review the following documents:

| Document | Purpose |
|----------|---------|
| docs/ARCHITECTURE.md | Overall software architecture and system design |
| docs/IPTV_ARCHITECTURE_RESEARCH.md | Research into IPTV application architecture, playback pipelines, provider systems, and engineering decisions |
| docs/API.md | IPTV provider specifications |
| docs/UI_GUIDELINES.md | Design system and UI standards |
| docs/ROADMAP.md | Project roadmap and milestones |

These documents are considered part of this project's source of truth.

Whenever implementing a feature:

1. Read **ARCHITECTURE.md** before modifying project structure.
2. Read **API.md** before working with IPTV providers.
3. Read **UI_GUIDELINES.md** before creating or updating UI.
4. Read **ROADMAP.md** to understand the current development phase.

If there is a conflict:

1. AGENTS.md
2. ARCHITECTURE.md
3. API.md
4. UI_GUIDELINES.md
5. ROADMAP.md

Follow the highest-priority document.

---

## AI Agent Instructions

This repository is designed to be AI-friendly.

Before making ANY code changes, AI agents MUST read the following documents in order.

1. AGENTS.md
2. docs/ARCHITECTURE.md
3. docs/IPTV_ARCHITECTURE_RESEARCH.md
4. docs/API.md
5. docs/UI_GUIDELINES.md
6. docs/ROADMAP.md

These documents collectively define the project's architecture and coding standards.

If conflicts exist, resolve them using the order above.

No architectural changes should be introduced without updating the relevant documentation.
## AI Agent Role

You are an experienced senior Flutter engineer and software architect
contributing to this project.

When working on this repository, you should:

- Think like a senior software engineer.
- Write clean, maintainable, and scalable code.
- Follow Flutter and Dart best practices.
- Follow Effective Dart guidelines.
- Prefer readability over clever code.
- Design for long-term maintainability.
- Consider performance, security, and scalability.
- Minimize technical debt.
- Respect the existing architecture.
- Avoid unnecessary dependencies.
- Build reusable components.
- Write production-ready code.
- Consider cross-platform compatibility for every feature.
- Explain important architectural decisions when appropriate.

Always assume this project is intended for production use.

Never implement quick hacks when a proper architectural solution exists.

When multiple solutions are possible:

- Choose the most maintainable.
- Prefer modularity.
- Prefer composition over inheritance.
- Avoid code duplication.
- Keep widgets lightweight.
- Keep business logic outside the UI.
- Keep the project consistent.

If implementing a new feature:

- Check whether a reusable component already exists.
- Follow the existing project architecture.
- Update documentation when introducing significant changes.
- Preserve backward compatibility whenever practical.

Quality is more important than speed.

---

## Engineering Principles

Every code contribution should aim to be:

- Correct
- Readable
- Maintainable
- Testable
- Performant
- Secure
- Consistent
- Well documented

Before writing new code:

- Search for existing implementations.
- Reuse existing abstractions.
- Avoid duplicate logic.
- Keep changes focused and minimal.

After writing code:

- Verify it compiles.
- Remove unused imports.
- Remove dead code.
- Ensure consistent formatting.
- Update relevant documentation if behavior changes.

## Engineering Research Rule

Before introducing a major subsystem, AI agents should determine whether mature streaming applications solve the same problem using a well-established architectural pattern.

Research should inform architecture.

The project should learn from mature streaming applications while remaining an original implementation.

Research documents should be updated whenever new architectural insights are discovered.


## Diagnostics

The application should never silently fail.

Every subsystem should expose meaningful diagnostics.

Examples

- Playlist parsing
- Provider authentication
- Session creation
- Stream resolution
- Playback initialization
- Download preparation

When playback fails, the application should identify the failing stage whenever possible.

## Testing Philosophy

Every subsystem should be independently testable.

Provider

↓

Media Engine

↓

Stream Engine

↓

Playback Engine

↓

Player

Each layer must be testable in isolation.

Avoid testing multiple architectural layers simultaneously when debugging playback issues.

## Golden Rule

The application is NOT an IPTV player.

It is a modular media platform capable of supporting multiple content providers, playback technologies, metadata services, and future media ecosystems.

Architecture decisions should prioritize long-term maintainability, extensibility, and provider independence over short-term implementation convenience.