# IJK Player Evaluation (Phase 3)

Status: experimental — opt-in only, excluded from `auto` selection.

## Motivation

All four shipping engines share one dependency on problem devices: the
Flutter external-texture pipeline (media_kit, VLC-in-Flutter) or MediaCodec
via ExoPlayer's renderer (Native Player, ExoPlayer SurfaceView). Devices
where every path fails have been observed in the field. IJKPlayer is an
FFmpeg-based Android player with its own JNI/SDL layer; evaluating it
answers two questions:

1. Does FFmpeg's demuxer/decoder tolerance rescue streams ExoPlayer cannot
   parse?
2. Does its render path behave on devices where Flutter textures and
   hybrid-composition platform views black-screen?

## Architecture Fit

IJK follows the standard playback pipeline exactly:

```
Stream Engine → PlayableSession → IjkPlayerAdapter → IjkPlayerActivity → IjkMediaPlayer
```

- `lib/core/media/player/ijk_player_adapter.dart` — Dart-side adapter,
  mirrors `NativeActivityPlayerAdapter` (launch + event channels).
- `android/app/src/ijk/kotlin/com/example/stream_hub/IjkPlayerActivity.kt` —
  window-owned
  `TextureView`, structured diagnostics (`NativePlaybackDiagnostics`
  categories), controlled reconnect budget (server-died only), render
  watchdog armed on prepared+playing.
- Deliberate omissions vs the production Native Player: no EPG drawer, no
  PiP, no gesture HUD, no quality menu. It is an A/B instrument, not a
  product surface.

## Isolation Policy

- `PlaybackEngineKind.ijk` / `PlaybackEnginePreference.ijk` exist end to end
  but `auto` never selects them and `fallbackOrderFor` never includes them.
- The engine only runs when the user pins it explicitly in Settings →
  Preferred Player ("IJK (Experimental)").
- IJK specifics (options, JNI error codes, reconnect policy) stay inside the
  adapter and Activity; the Playback Engine sees only `PlayerAdapter`.

## Wire Protocol

Launch channel: `stream_hub/ijk_player_launch` — methods `launch`, `play`,
`pause`, `stop`, `seekTo`, `setVolume`, `setMuted`, `setSpeed`, `reload`.
Events channel: `stream_hub/ijk_player_events` — `onState{state}`,
`onPosition{positionMs,bufferedMs,durationMs}`, `onVideo{width,height}`,
`onError{message,category,httpCode}`, `onFinished`.
Error categories reuse the `NativePlaybackDiagnostics.ErrorCategory` wire
names so the diagnostics pipeline treats all engines uniformly.

## IJK Version (Required Documentation §34)

| Field            | Value                                                        |
| ---------------- | ------------------------------------------------------------ |
| Repository       | https://github.com/bilibili/ijkplayer.git                    |
| Commit / version | `k0.8.8` (override with `IJKPLAYER_COMMIT` before building)  |
| NDK              | llvm/clang-based Android NDK, r19c or newer (set `ANDROID_NDK`) |
| NDK API          | `21` (override `IJK_NDK_API`)                                |
| ABIs built       | `arm64-v8a`, `armeabi-v7a`                                   |
| Patches          | NDK/clang toolchain retarget (gcc prebuilt → llvm prebuilt); see `tools/streamhub-build.sh` |

`k0.8.8` predates NDK r22 (gcc removal). The build script applies
idempotent patches that retarget the legacy `toolchains/<arch>-linux-android-4.9`
gcc prebuilts to the unified `toolchains/llvm/prebuilt` clang toolchain so the
sources compile with a modern NDK. If you pin a newer commit, trim/adjust the
patches as needed.

## Build & Vendor Pipeline

The upstream Gradle build does not run under modern JDKs, so the StreamHub
build bypasses Gradle entirely and builds from a pinned source checkout:

```
tools/streamhub-build.sh     # clones bilibili/ijkplayer @ IJKPLAYER_COMMIT
  1.   init ffmpeg/openssl submodule sources (init-android.sh)
  2.   apply NDK/clang-compat patches (idempotent, marked)
  3.   compile openssl + ffmpeg per arch (arm64, armv7a)
  4.   ndk-build ijkplayer native layers per arch
  5.   package ijkplayer-java AAR manually (javac against android.jar)

tools/ijkplayer/vendor.sh    # copies the produced artifacts into this repo
  android/app/libs/ijkplayer-java-release.aar
  android/app/src/main/jniLibs/<abi>/lib{ijkplayer,ijksdl,ijkffmpeg}.so
```

Tunables (environment): `IJKPLAYER_REPO`, `IJKPLAYER_COMMIT`, `IJK_ARCHS`,
`IJK_NDK_API`, `IJK_SDK_API`, `IJK_BUILD_ROOT`, plus `ANDROID_NDK` and
`ANDROID_SDK`. `IJK_BUILD_ROOT` defaults to `../stream_hub_tmp_ijk/ijkplayer`,
which is exactly where `vendor.sh` looks.

The vendored AAR gates compilation: when `android/app/libs/
ijkplayer-java-release.aar` is absent, Gradle compiles the engine out
entirely (its Kotlin source set and manifest are excluded and the launch
channel registration no-ops via reflection), so the rest of the app builds
and runs unchanged. Run `vendor.sh` to enable it.

## Evaluation Method

For each problem stream/device pair, run the same URL through every engine
(Settings → Preferred Player) and record: time to first frame, rebuffer
frequency, decode errors (category counts from diagnostics), and audio/video
drift. Promote IJK out of experimental status only if it beats the current
best engine on a class of streams without regressing elsewhere; otherwise
remove the backend entirely (the isolation policy guarantees removal touches
only the adapter, activity, enum values, and this document).
