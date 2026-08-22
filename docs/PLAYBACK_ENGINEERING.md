# Playback Engineering

> Status: Implemented (feature/pluggable-playback-engines)

This document records why StreamHub Pro ships a pluggable playback backend,
the root cause of the live-TV black-screen defect it addresses, and the
selection/fallback policy the `PlaybackEngine` enforces.

Related documents: `ARCHITECTURE.md` (Player Adapter, Playback Engine
Selection), `API.md` (provider contracts), `AGENTS.md` (Golden Rule).

---

## 1. Problem: audio plays, video stays black after buffering

Users on some Android devices reported Live TV streams that start with audio
but never show video once playback buffers. MediaKit (libmpv) is the primary
backend, so the failure lived in the media_kit native render path.

### 1.1 Root cause

- media_kit 1.1.5 (`PlayerConfiguration`) exposes vo/osc/pitch/libass/
  log-level/buffer-size/protocol-whitelist flags but **no hardware-decode
  control**. The `Video` widget builds a 1-pixel texture first and resizes it
  once the real frame arrives (`video_texture.dart`). The native EGL texture
  handshake can fail with `EGL_BAD_ATTRIBUTE` on certain GPU/driver combos
  (previously triggered under both Skia and Impeller on emulators); audio
  keeps playing while the video texture never updates → black screen.
- There is no way to force a software path or a different render surface
  through the current media_kit API, so the defect is not fixable inside the
  media_kit integration without upgrading/replacing the render layer.
- Re-confirmed on a real Android device (Unisoc SoC / Mali GPU, Android 11+):
  with Impeller enabled the log shows the native decoder and surface texture
  working correctly — `setSurfaceTextureSize ... 1920 816` and
  `VideoOutput.WaitUntilFirstFrameRenderedNotify` both fire — while the screen
  stays black and audio plays. The frames reach the Flutter `Texture`, but the
  Impeller compositor fails to sample it on this device class
  (media-kit/media-kit#837). The failure is silent: no Dart exception is
  raised, so no runtime fallback can detect it.
- The renderer opt-out `io.flutter.embedding.android.EnableImpeller=false` is
  re-enabled in `AndroidManifest.xml`; it remains the official deployment
  mechanism (https://docs.flutter.dev/perf/impeller) and matches
  media-kit/media-kit#837. An earlier removal of the opt-out was based on the
  incorrect belief that Flutter 3.41 deprecates the flag, which is not the
  case.
- **However, a real-device retest proved the opt-out alone is insufficient on
  Unisoc/Mali hardware.** With Impeller disabled the screen was still black.
  Logcat showed `c2.unisoc.avc.decoder` + `NdkMediaCodec` (media_kit hardware
  decode) feeding `SurfaceTexture-0-28037-1` until
  `dequeueBuffer: BufferQueue has been abandoned`; codec output buffers were
  never recycled (`0/4 (recycle/alloc)` with 745 transfers) and the decoder
  starved (`only 3 buffers allocated`). The failure is a dead Flutter
  **external-texture consumer**, not an Impeller-vs-Skia compositing choice.
- **Definitive device diagnosis (logcat PID 5175, 2026-08):** the failure is
  Flutter's GL compositor being unable to sample the video `SurfaceTexture`.
  Every sampled frame logs `[SurfaceTexture-0-5175-2] bindTextureImage:
  clearing GL error: 0x505` — `0x505` is `GL_INVALID_OPERATION`, cleared by
  Android's `GLConsumer.bindTextureImageLocked()`
  (frameworks/native/libs/gui/GLConsumer.cpp). The buffer pool shows
  `0/4 (recycle/alloc)` against `4/588 (fetch/transfer)` — the consumer never
  recycles — followed by `dequeueBuffer: BufferQueue has been abandoned` and
  `MediaCodec: Pending dequeue output buffer request cancelled` (-38) as the
  decoder tears down. Decode itself works (`c2.unisoc.avc.decoder`, 1920×816
  frames reach the texture); audio plays; only the Flutter external-texture
  sampling fails, silently. PID 5175 ran under **auto engine selection** (the
  `NdkMediaCodec` tags indicate media_kit was the active backend), and the
  earlier explicit-VLC test on the same device also showed black — both engines
  route video through Flutter's `TextureRegistry`, so **engine switching cannot
  fix this device class**. Documented limitation: Flutter external-texture
  video is unsupported on this Unisoc/Mali device; a native-SurfaceView render
  path would be required to display video there (§8).
- Because it raises no Dart exception, the engine can only react by polling.
  `PlaybackEngine` tracks whether the media_kit adapter ever reported a video
  frame (`VideoParams.w/h > 0`); after 10s of "playing with no frame" it
  force-swaps to VLC and reloads the session (§2).
- **Watchdog limitation (proven on device):** `hasVideoFrames` keys off
  `VideoParams.w/h`, which media_kit reports with real dimensions (e.g.
  1920×816) the moment decoding starts. On Unisoc/Mali the decoder *does*
  produce frames; only the Flutter external-texture consumer never renders
  them. So `hasVideoFrames` stays `true`, the watchdog counter resets every
  poll and the fallback never fires (confirmed: no `Black screen detected`
  log and no VLC session in a PID 31137 logcat). The watchdog cannot detect
  this defect class and is effectively dead code for it.

### 1.2 Why VLC

`flutter_vlc_player` bundles libvlc's robust network stack. **It does NOT
bypass Flutter external textures by default**: `FlutterVlcPlayer.java` calls
`textureRegistry.createSurfaceTexture()` (line 113), so with the default
`virtualDisplay: true` the plugin renders through an `AndroidView` → Flutter
external-texture sampler — the same dead consumer that black-screens
media_kit. That is why selecting VLC showed black too (user test, device).

The adapter forces `virtualDisplay: false`, which selects Android **hybrid
composition** (`PlatformViewLink` + `initSurfaceAndroidView`) instead of the
plain `AndroidView` path. **This does NOT bypass Flutter's external-texture
consumer**: the plugin still calls `textureRegistry.createSurfaceTexture()`
(FlutterVlcPlayer.java:113) and attaches that `SurfaceTexture` to its
`VLCTextureView` (a `TextureView`; `onSurfaceTextureUpdated` is empty at
VLCTextureView.java:155, and no `markTextureFrameAvailable` call exists in the
plugin). Frames still reach Flutter's GL compositor, which is where
`GL_INVALID_OPERATION` (0x505) is cleared on this device (§1.1). Hybrid
composition is therefore a **best-effort** render-mode change, not a confirmed
fix, and it has **not been validated on-device** (the 2026-08 log was
auto-selection/media_kit; the explicit-VLC test predates this flag). The
Unisoc/Mali device class is documented as unsupported for Flutter
external-texture video (§1.1, §8).

VLC also bundles:

- `--http-reconnect` for flaky relays
- live/network cache tuning
- RTSP/RTP-over-TCP, UDP multicast, RTMP (librtmp)
- header mapping (User-Agent / Referer / Cookie) via access options

That makes VLC the resilient engine for Live TV, HLS, MPEG-TS and
RTSP/RTMP/UDP/RTP — the exact class of streams affected by the defect — while
MediaKit remains the default for VOD and modern HTTP(S) adaptive playback.

### 1.3 Constraint check

- Keep media_kit: yes. It stays the engine for VOD/progressive/DASH and the
  platform fallback where VLC is unsupported (Desktop, Web).
- No UI rewrites: the player pages now render through
  `PlayerAdapter.buildPlayerWidget()`; the rest of the player UI is untouched.
- Clean Architecture + GetX: adapters/strategy/factory live in
  `core/media/player`, the engine owns selection, controllers stay thin.

---

## 2. Architecture

```
Playback Engine (PlaybackEngine)
   │  selects per session (Auto) or per explicit preference
   ▼
PlayerAdapterFactory.create(kind)
   │
   ├─ MediaKitPlayerAdapter   (all platforms)
   └─ VlcPlayerAdapter        (Android/iOS, gated by VlcPlayerAdapter.isSupported)
```

- `PlayerAdapter` contract: `kind`, `isInitialized`, `buildPlayerWidget()`,
  plus the existing transport/control surface.
- `PlayerSelectionStrategy` resolves URL + media type + user preference into a
  `PlaybackEngineKind`. `PlayerNegotiator` (protocol-only) must stay
  consistent with it.
- `PlaybackEngine`:
  - `engineKindRx` exposes the active backend to the UI.
  - `_maybeSelectEngineForUrl` is invoked on every session load when in Auto
    mode; `_swapAdapter` disposes the old backend and rebinds the stream
    subscriptions so no stale adapter feeds the engine.
  - `_tryEngineFallback` swaps to the alternate backend once per session,
    only in Auto mode, only when the user preference is `auto`, and only when
    the alternative backend is available on the platform. Since Phase 2 it is
    additionally gated by the structured error category (§9.4): auth /
    not-found / rate-limited failures surface directly instead of triggering
    a futile backend swap.
- `PlayerSettings.preferredPlayer` (`auto | mediaKit | vlc`) is persisted in
  Hive (`PlayerSettingsModel`, `@HiveField(18)`) and drives the policy.
  - Persistence is registered at startup in `MediaBinding`
    (`PlaybackLocalService` + `PlaybackRepository` via `Get.put(..., permanent: true)`,
    with `unawaited(service.init())`), exposed as `PlaybackRepository`.
  - `PlayerController.onInit` loads the persisted settings and calls
    `PlaybackEngine.applySettings` before the first session, so backend
    selection honors the user's preference.
  - Settings → Playback exposes a "Preferred Player" picker
    (Auto / MediaKit / VLC) that writes straight through the repository.

### 2.1 Policy (Auto mode)

| Stream class                              | Engine    |
|-------------------------------------------|-----------|
| RTSP / RTMP / RTMPS / UDP / RTP           | VLC       |
| HLS (live), MPEG-TS, live HTTP(S) relay   | VLC       |
| DASH / MP4 / MKV / progressive HTTP(S)    | MediaKit  |
| Unknown protocol                          | none      |

An explicit engine kind or an injected adapter disables selection and
fallback (used by tests).

### 2.2 Fallback flow

1. Engine loads the session on the selected backend.
2. On failure, `_tryEngineFallback()` swaps to the alternate backend and
   reloads once.
3. If the alternate also fails (or fallback is disabled), the engine emits
   `PlaybackState.error` with the failing stage in the message.

The fallback only works if a backend failure *reaches* the engine. VLC init is
therefore driven explicitly by the adapter (`autoInitialize: false` +
`await controller.initialize()` after the platform view mounts) instead of the
plugin's fire-and-forget `onPlatformViewCreated` path — otherwise a native VLC
init failure (e.g. `channel-error: Unable to establish connection on channel.`
on devices where the VLC plugin is unavailable) escapes as an unhandled async
error and playback hangs with an empty buffer while Auto mode never falls back
  to MediaKit.

The fallback originally could not catch the black-screen defect: the failure is
a native compositor/external-texture issue that raises no Dart exception, so
the engine never learned the frame wasn't displayed. That is now handled by the
silent black-screen watchdog (§1.1): the engine polls the media_kit adapter for
`VideoParams.w/h > 0` while playing, and after 10s with no frame it invokes
`_tryEngineFallback()` and reloads the current session on VLC. The
`EnableImpeller=false` opt-out remains in place (§1.1) as a cheap mitigation for
devices where Skia composites external textures correctly, but it is no longer
the primary mechanism.

---

## 3. VLC limitations (documented behavior)

- No arbitrary HTTP header injection. User-Agent, Referer and Cookie are
  mapped to VLC access options; other headers (e.g. `Authorization`) must be
  embedded in the stream URL by the Stream Engine.
- Quality selection is not supported (`getAvailableQualities` reports
  `[auto]`); the UI already gates on capabilities.
- No audio/spu language metadata (track id + label only).
- `setAspectRatio` maps only 16:9 and 4:3 to libvlc; other modes are ignored.
- Backend is Android/iOS only; other platforms always select MediaKit.
- Initialization is driver-controlled, not widget-driven: the controller is
  created with `autoInitialize: false` and `VlcPlayerAdapter._initializeController`
  polls `VlcPlayerController.isReadyToInitialize` (set once the `VlcPlayer`
  widget mounts its platform view), then awaits `initialize()`. This guarantees
  native init failures propagate through `playSession` into the engine's Auto
  fallback instead of surfacing as unhandled async errors. VLC methods are
  guarded against uninitialized controllers (`stop`, `pause`, `dispose`) so a
  failed init can never crash the route-pop/dispose path.

---

## 4. Migration / rollout

- `preferredPlayer` defaults to `auto`, so existing installs gain VLC for
  live/HLS/RTSP without a user action.
- Android: `android/app/build.gradle.kts` enables
  `jniLibs { useLegacyPackaging = true }` for libvlc `.so` packaging.
- Android: `android/app/src/main/AndroidManifest.xml` sets
  `io.flutter.embedding.android.EnableImpeller=false` (official deployment
  mechanism; kept as a cheap mitigation). A real-device retest showed the
  opt-out alone does not fix Unisoc/Mali black screens, and the silent
  black-screen watchdog cannot detect the defect either (§1.1). The current
  mitigation is VLC with `virtualDisplay: false` (hybrid composition, §1.2) —
  best-effort and not validated on-device; the defect is documented as a
  device-class limitation (§1.1).
- Manual QA on a device that reproduced the black screen: open a live channel
  (HLS/TS), confirm video renders, then verify VOD (MP4) still uses MediaKit.
  Retest history on a real Unisoc/Mali device:
  1. media_kit, Impeller on: **black** (frames decoded, external-texture
     consumer dead).
  2. media_kit, Impeller off (`EnableImpeller=false`): **still black**.
  3. VLC (`virtualDisplay: true`, default): **still black** — expected, because
     `flutter_vlc_player` also routes through Flutter's external-texture
     sampler in that mode (§1.2).
  4. VLC (`virtualDisplay: false`, hybrid composition): **not exercised in
     isolation** — the 2026-08 log (PID 5175) ran under auto engine selection
     (media_kit, per `NdkMediaCodec`), and hybrid composition does not bypass
     the external-texture consumer anyway (§1.2). No further experiments are
     planned; the device class is documented as unsupported for Flutter
     external-texture video (§1.1, §8).
- Watchdog note: the 10s no-video-frame watchdog was proven unable to detect
  the defect (media_kit reports real `VideoParams` once decode starts, so
  `hasVideoFrames` never goes false; no `Black screen detected` log in
  PID 31137). It remains in the code as a best-effort guard but is not the
  mechanism relied on for this defect class.
- To confirm the opt-out itself reached the build, check the installed APK's
  merged manifest for `io.flutter.embedding.android.EnableImpeller=false` (or
  the engine log line `Using the Skia rendering backend` in debug).
- The engine logs every selection and fallback (`PlaybackEngine` tag), which
  surfaces the active backend in diagnostics.

---

## 5. Verification

- `dart analyze` — clean.
- `flutter test` — 316 passing, including:
  - `test/player/buffer_info_test.dart` (VOD vs live/unbounded health semantics
    for the black-screen-fix diagnostic fix).
  - `test/iptv/stream_negotiation_engine_test.dart` (updated to the new
    VLC-preferred HLS/UDP policy).
  - `test/player/player_controller_test.dart` (explicit-adapter path, fallback
    disabled).
  - `test/xtream/xtream_media_source_test.dart` (invalid-credentials and
    empty-panel sync now fail with actionable messages).
  - `test/player/error_classification_test.dart` (wire-name round-trip and
    the engine-fallback policy of §9.4).
- Build runner note: `hive_generator` (analyzer 2.19) cannot parse Dart 3.11
  sources (e.g. records in `url_normalizer.dart`), so committed `.g.dart`
  stubs are the source of truth. Do not run `build_runner build
  --delete-conflicting-outputs` against this tree; it deletes the committed
  stubs and cannot regenerate them.

---

## 6. Runtime diagnostics notes

Observations from on-device runs that are expected behavior, not defects:

- **`media_kit: WARNING: package:media_kit_native_event_loop not found`**
  (Android): the `media_kit_native_event_loop` package ships native builds for
  desktop and iOS only — there is no `android/` build. media_kit detects the
  missing native library and falls back to the Dart isolate event loop
  automatically. The warning is benign; playback is unaffected.
- **Xtream sync imports zero items**: an Xtream panel that rejects the
  credentials returns `[]` for every list endpoint while the app has no way to
  tell "empty account" from "wrong credentials" unless the panel's `user_info`
  is consulted. `XtreamMediaSource` now:
  - records the panel `user_info.auth` flag and fails sync with an
    "invalid credentials" message when `auth == 0`;
  - fails sync with an actionable message when every list returns empty AND
    `user_info` could not be fetched;
  - redacts the credentials from the URL in all log output
    (`SensitiveDataRedactor`).
  A legitimately empty account (valid auth, zero items) still reports success.
- **`"PlaybackLocalService" not found` on the player route**: caused by
  registering the service with `Get.putAsync` (non-permanent). `putAsync` only
  inserts the instance into the GetX singleton map after the future completes,
  and non-permanent instances registered from the initial binding are disposed
  by GetX smart management once the initial route is popped — so a later
  synchronous `Get.find` from the player route fails even though the service
  logged "initialized" at startup. Fixed by registering long-lived local
  services with `Get.put(..., permanent: true)` + `unawaited(init())` (the same
  pattern `ProviderSessionLocalService` uses). Note: in `get` 4.7.3 the
  `Get.lazyPut` extension only accepts `{tag, fenix}` (no `permanent`), so
  eagerly `Get.put(..., permanent: true)` is the supported way to make a
  repository app-lifetime.

---

## 7. Android emulator cannot render video (environment limitation)

Neither backend can render video on the Android emulator. This is an upstream
environment limitation, **not** an app defect. The Auto-fallback and engine
selection are verified working; the emulator simply has no GLES path that
libmpv or libvlc accept.

### 7.1 Symptoms

- **VLC**: `PlatformException(channel-error, Unable to establish connection on
  channel. ...)` thrown from `VlcPlayerApi.initialize` — the libvlc native
  channel never registers on the emulator.
- **MediaKit**: `E/EGL_emulation: eglCreateContext(...): error 0x3004
  (EGL_BAD_ATTRIBUTE)` after `AndroidVideoController: Enforcing S/W
  rendering.` — libmpv's EGL context is rejected by the emulator's GLES
  translator. The engine still reports `Session loaded` (the failure is an
  async native log that never reaches Dart), so playback hangs with no error.
  (A misleading `Buffer unhealthy: 0.0%` warning previously accompanied this;
  the `BufferInfo.isHealthy` fix now treats unbounded/live streams as healthy
  because they have no duration to compute a percentage against, and the stall
  is surfaced through the adapter's buffering state machine instead.)
- Reproduced on `swiftshader_indirect` and `-gpu host` (AMD Radeon translator)
  on a `Pixel_7_Pro_API_36` AVD. `angle_indirect` is Windows-only, so no other
  GPU mode is available on macOS hosts.
- **NativePlayerActivity** (ExoPlayer + plain SurfaceView, composited by
  SurfaceFlinger) decodes but does NOT display on the emulator either:
  `c2.goldfish.h264.decoder` produces frames and the buffer pool cycles (e.g.
  31457280-size buffers at 1080p), audio decodes, and `Session loaded` is
  reached — yet the SurfaceView stays black. The emulator's GLES/SurfaceFlinger
  translator fails to composite the video surface layer regardless of backend.
  This is still an environment limitation, not an app defect: the native path
  gets strictly further than media_kit (which dies with `EGL_BAD_ATTRIBUTE`),
  and the emulator log is the fastest end-to-end verification of the engine
  swap + native launch + decode pipeline.

### 7.2 Upstream status

- media-kit/media-kit#1343 — "[Android Emulator] Video not visible — only
  black screen displayed" (open since Dec 2025, reproduced on media_kit_video
  2.0.1): identical `EGL_BAD_ATTRIBUTE` signature.
- media-kit/media-kit#462 — maintainer: "We enforce software rendering in
  emulators ... but it seems it still doesn't work in some cases."
- VLC on the emulator fails earlier (native channel registration), so the VLC
  backend cannot render there either.

### 7.3 Working verification path

The pipeline is proven on macOS, where media_kit uses a working rendering path
(native video output, not the EGL texture handshake). Smoke test:

```
flutter test integration_test/macos_playback_smoke_test.dart -d macos \
  --dart-define=LIVE_STREAM_URL=your-stream-url
```

The test drives the real `MediaKitPlayerAdapter` with a `PlayableSession`,
asserts the player reaches `playing`, video dimensions are resolved (e.g.
1920x1080), and the position advances. Defaults to a public HLS test stream.
This is the same adapter/engine code path used on Android, so a passing run
confirms the fallback + rendering logic; the emulator EGL bug is orthogonal.

### 7.4 macOS build prerequisites (documented fixes)

The macOS target needed several fixes to build and run at all:

- **Entitlements**: `DebugProfile.entitlements` and `Release.entitlements`
  lacked `com.apple.security.network.client`, so the sandboxed app could not
  open live stream connections. Added to both.
- **Podfile** `post_install` hooks:
  - strips the malformed gRPC BoringSSL per-file compiler flag
    `-GCC_WARN_INHIBIT_ALL_WARNINGS` (rejected as `unsupported option '-G'`
    by newer clang);
  - adds `-Wno-missing-template-arg-list-after-template-kw` to the `gRPC-Core`
    and `gRPC-C++` targets (gRPC ~1.62 uses `Traits::template
    CallSeqFactory(...)`, a default error in Xcode 26's clang).
- **pubspec**: `google_sign_in_ios` pinned to `5.8.1` — `5.9.0` requires
  `GoogleSignIn ~> 8.0`, whose transitive `AppCheckCore` needs
  `GoogleUtilities ~> 8.0`, incompatible with the Firebase 10.x SDK
  (`GoogleUtilities ~> 7.x`) on Apple pod resolution. `5.8.1` uses
  `GoogleSignIn ~> 7.1`.
- **`macos/Runner/GoogleService-Info.plist`**: a real Firebase config is now
  generated with `flutterfire configure` (uses the iOS-registered app for the
  macOS bundle id `com.example.streamHub`; no new console app is created).
  Required because the `Runner` target declares it as a build resource and
  `FLTFirebaseCorePlugin` auto-configures the default app at launch — an
  absent or placeholder plist either crashed at `+[FIRApp configure]` (nil
  values) or left Firebase in local/cached mode, blocking sign-in.
  Verified on macOS: `Firebase initialization successful.` followed by a real
  `Email login successful` auth. Note the plist contains **no
  `CLIENT_ID`/`REVERSED_CLIENT_ID`** — the Firebase project has no Google
  Sign-In OAuth client (Android's `google-services.json` also lists an empty
  `oauth_client`), so `signInWithGoogle` is unavailable on every platform until
  Google Sign-In + an OAuth client are configured in the Firebase console.
  All Firebase config files (`firebase_options.dart`, plists,
  `google-services.json`, `firebase.json`) are gitignored and must be
  regenerated on a fresh checkout with `flutterfire configure`.
- **Xcode project** `FlutterFire: "flutterfire upload-crashlytics-symbols"`
  run-script phase now exits early when `firebase.json` is absent, so the
  build does not fail on machines without a Firebase config.

## 8. Documented device limitation: Flutter external-texture video on Unisoc/Mali

**Status: mitigated on-device via the native Activity render path (§8.3).
The raw Flutter external-texture defect itself remains unsolved and unsolvable
in-app.**

### 8.1 What is unsupported

On the test device (Unisoc SoC / Mali GPU, Android 11+), video displayed
through Flutter's external-texture compositor never renders: the audio plays,
the decoder produces frames, but the screen stays black. This affects **every**
playback backend built on Flutter's `TextureRegistry` — media_kit and
`flutter_vlc_player` 7.4.4 both call `textureRegistry.createSurfaceTexture()`
and rely on Flutter's GL sampler to composite the video. Engine switching
cannot work around it by design.

### 8.2 Evidence

- `GLConsumer.bindTextureImageLocked()` (frameworks/native/libs/gui/
  GLConsumer.cpp) clears `GL_INVALID_OPERATION` (0x505) on every sampled
  frame: `[SurfaceTexture-0-5175-2] bindTextureImage: clearing GL error:
  0x505`.
- The consumer never recycles producer buffers: `0/4 (recycle/alloc)` vs
  `4/588 (fetch/transfer)`, then `dequeueBuffer: BufferQueue has been
  abandoned` and the decoder starves (`MediaCodec: Pending dequeue output
  buffer request cancelled`, -38).
- Same signature across engine configs: media_kit + Impeller, media_kit +
  Skia (`EnableImpeller=false`), and VLC (`virtualDisplay: true`) all show
  black on this device (retest history §4).
- The failure is silent at the Dart layer: no exception, no failed stream
  state, so no runtime fallback can detect or react to it (§1.1 watchdog
  limitation).

### 8.3 Mitigation: Native Player Activity (implemented)

A native render path that bypasses Flutter's external-texture sampler **is now
implemented**: `NativePlayerActivity` (Android) hosts ExoPlayer + TextureView
in a plain `Activity`, rendered directly by the app's view system
(SurfaceFlinger), outside the Flutter view hierarchy. `PlaybackEngine` selects
it through `PlaybackEngineKind.nativeActivity`
(`NativeActivityPlayerAdapter`).

- **Live** (MPEG-TS/HLS/HTTP(S) relays): routed to the native Activity by the
  `PlayerSelectionStrategy` in Auto mode on Android.
- **VOD** (MP4/MKV/DASH): the strategy keeps VOD on media_kit by default, so
  VOD only reaches the native Activity when `HardwareDetector.isUnisocOrMali()`
  forces it. The detector matches Unisoc UMS part numbers (`ums9230` on the
  itel C671L, i.e. Tiger T606), the older Spreadtrum `SP`/`SC`/`sprd` strings,
  and Mali-paired MediaTek/Exynos parts.
- The Activity owns its transport bar (play/pause, rewind/forward, **stop**,
  quality) and a **close (✕)** button; closing it finishes the Activity and
  emits `onFinished`, and the fullscreen page pops itself.
- The Flutter transport bar also gained a **stop** button
  (`PlayerController.stopAndClose`) that stops playback and leaves the player
  route, skipping the explicit pop for the native-activity adapter (its
  Activity self-close already pops the page).

The Activity path renders video with ExoPlayer + TextureView (live proven on
the itel C671L). VOD verification is in progress (§8.4).

---

## 9. Structured playback-error classification and fallback policy

Phase 2 of the playback-hardening work: every Android ExoPlayer failure is
classified once, at the source, and the classification drives recovery — no
string sniffing, no blind retries.

### 9.1 Classification (native side)

`NativePlaybackDiagnostics` (Kotlin) owns an `ErrorCategory` enum and a pure
`classifyPlaybackException()` mapper from Media3 `PlaybackException`
(`errorCode`) plus the optional `httpStatusCode` to:

| Category | Typical cause |
|---|---|
| `NETWORK` | DNS, timeout, connection reset/refused |
| `SERVER` | HTTP 5xx from the stream server |
| `AUTH` | HTTP 401/403 — expired credentials, IP lock, UA block |
| `NOT_FOUND` | HTTP 404/410 |
| `RATE_LIMITED` | HTTP 429 — provider throttling |
| `MEDIA` | Malformed container / manifest parsing |
| `DECODER` | MediaCodec init or runtime decode failure |
| `RENDERER` | Output pipeline failure (surface, no frames rendered) |
| `UNKNOWN` | Anything else |

Both native backends (`NativePlayerActivity`, `ExoPlayerSurfaceView`)
attach `category` and `httpCode` to every error they emit across the
method/event channels, alongside the human-readable message. Errors are never
logged with full authenticated URLs; diagnostics use `sanitizeUrl()`
(query-string stripped).

### 9.2 Render watchdog

Both native backends arm a watchdog when playback reaches `STATE_READY` with
`playWhenReady` and a video track: if no frame has rendered after 10 s
(8 s on the Unisoc/Mali Activity path), the backend emits a structured
`RENDERER` error instead of leaving the screen black forever. The watchdog is
cancelled by the first rendered frame or any state/pause change.

### 9.3 Dart contract (`error_classification.dart`)

`NativeErrorCategory` mirrors the Kotlin enum;
`StructuredErrorReporter` is implemented by both native adapters and exposes
`lastErrorCategory`, `lastErrorHttpCode`, and `clearLastError()`. Adapters
clear the stored classification on every new load so a past failure can never
influence a later decision.

### 9.4 Engine-fallback policy

`shouldAttemptEngineFallback(category)` gates `PlaybackEngine._tryEngineFallback`:

- `null` (backend without classification) → fall back (legacy behavior).
- `AUTH`, `NOT_FOUND`, `RATE_LIMITED` → **never** fall back: these are
  properties of the stream/provider. Every engine receives the same HTTP
  answer, so swapping backends cannot help — it only delays the visible error
  and hammers throttling providers further.
- everything else (`NETWORK` exhausted after native retries, `SERVER`,
  `MEDIA`, `DECODER`, `RENDERER`, `UNKNOWN`) → fall back; a different demuxer,
  decoder set, or HTTP stack may genuinely succeed.

### 9.5 Stale-recovery guard (`PlayerController`)

Error recovery runs asynchronously; without a guard, a recovered session for
channel A can replay *after* the user already switched to channel B or pressed
stop ("zombie channel"). Two mechanisms prevent this:

- `_playGeneration` — a monotonic token bumped on every `playMediaItem` load
  and on `stop()`. Recovery captures the token at failure time and discards
  its replay when it has moved on.
- `_recoveryInFlightForItemId` — prevents two concurrent recoveries for the
  same item; the first to finish owns the replay.

