#!/usr/bin/env bash
#
# StreamHub Pro - Phase 3 playback-engine evaluation: IJKPlayer source build.
#
# This is the upstream half of the vendoring pipeline. Running this script
# produces the self-built ijkplayer artifacts that tools/ijkplayer/vendor.sh
# then copies into android/app/libs and android/app/src/main/jniLibs:
#
#   1. Clone bilibili/ijkplayer at a pinned commit (see IJKPLAYER_COMMIT).
#   2. Fetch the ffmpeg + openssl submodule sources (init-android.sh +
#      init-android-openssl.sh — upstream's init-android.sh does not pull
#      openssl, which the ffmpeg build links against).
#   3. Apply NDK/clang-compatibility patches so the legacy build scripts run
#      under a modern (llvm-based) Android NDK (r19c+).
#   4. Build ffmpeg + openssl for arm64 and armv7a.
#   5. Build the ijkplayer native layers (ndk-build) for arm64 and armv7a.
#   6. Package the ijkplayer-java AAR manually (javac against android.jar),
#      because the in-tree Gradle build does not run under current JDKs.
#
# The output layout matches what tools/ijkplayer/vendor.sh reads:
#   android/ijkplayer/ijkplayer-java/build/aar/ijkplayer-java-release.aar
#   android/ijkplayer/ijkplayer-<arch>/src/main/libs/<abi>/lib{ijkplayer,ijksdl,ijkffmpeg}.so
#
# Required environment:
#   ANDROID_NDK        Path to an llvm/clang-based Android NDK (r19c or newer).
#                      ANDROID_NDK_HOME is accepted as a fallback.
#   ANDROID_SDK        Path to the Android SDK (used for android.jar when
#                      packaging the AAR). ANDROID_HOME / ANDROID_SDK_ROOT
#                      are accepted as fallbacks.
#
# Tunables (override via environment):
#   IJKPLAYER_REPO     Upstream git remote (default: bilibili/ijkplayer).
#   IJKPLAYER_COMMIT   Exact tag/branch/sha to build (default: k0.8.8).
#                      NOTE: k0.8.8 predates NDK r22 (gcc removal). The patches
#                      below retarget the build to the llvm/clang toolchain so it
#                      builds with modern NDKs; if you pin a newer commit you may
#                      need to trim or adjust them.
#   IJK_ARCHS          Space-separated arch list (default: "arm64 armv7a").
#   IJK_NDK_API        Minimum Android API for the native build (default: 21).
#   IJK_SDK_API        Android SDK platform used to compile the Java AAR
#                      (default: highest installed android-* platform).
#   IJK_BUILD_ROOT     Where the ijkplayer tree is checked out. Must match the
#                      path vendor.sh expects (default: ../stream_hub_tmp_ijk/
#                      ijkplayer relative to this repo).
#
# Usage:
#   tools/streamhub-build.sh            # build with current env
#   IJKPLAYER_COMMIT=abcdef tools/streamhub-build.sh
#   tools/streamhub-build.sh && tools/ijkplayer/vendor.sh
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# ---------------------------------------------------------------------------
# Configuration (override via environment)
# ---------------------------------------------------------------------------
IJKPLAYER_REPO="${IJKPLAYER_REPO:-https://github.com/bilibili/ijkplayer.git}"
IJKPLAYER_COMMIT="${IJKPLAYER_COMMIT:-k0.8.8}"
IJK_ARCHS="${IJK_ARCHS:-arm64 armv7a}"
IJK_NDK_API="${IJK_NDK_API:-21}"
IJK_BUILD_ROOT="${IJK_BUILD_ROOT:-$REPO_ROOT/../stream_hub_tmp_ijk/ijkplayer}"

ANDROID_NDK="${ANDROID_NDK:-${ANDROID_NDK_HOME:-}}"
ANDROID_SDK="${ANDROID_SDK:-${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}}"

HOST_TAG="$(uname -s | tr '[:upper:]' '[:lower:]')-x86_64"
case "$(uname -s)" in
  Darwin) HOST_TAG="darwin-x86_64" ;;
  Linux)  HOST_TAG="linux-x86_64" ;;
  *) echo "Unsupported host OS: $(uname -s)" >&2; exit 1 ;;
esac

# ---------------------------------------------------------------------------
# Preconditions
# ---------------------------------------------------------------------------
need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1" >&2; exit 1; }; }
need_cmd git
need_cmd bash

if [ -z "$ANDROID_NDK" ] || [ ! -d "$ANDROID_NDK" ]; then
  echo "ANDROID_NDK is not set or does not exist." >&2
  echo "Set ANDROID_NDK (or ANDROID_NDK_HOME) to an llvm/clang-based NDK (r19c+)." >&2
  exit 1
fi
if [ -z "$ANDROID_SDK" ] || [ ! -d "$ANDROID_SDK" ]; then
  echo "ANDROID_SDK is not set or does not exist." >&2
  echo "Set ANDROID_SDK (or ANDROID_HOME / ANDROID_SDK_ROOT)." >&2
  exit 1
fi

# Pick the highest installed SDK platform for the Java AAR compile.
if [ -z "${IJK_SDK_API:-}" ]; then
  IJK_SDK_API="$(ls "$ANDROID_SDK/platforms" 2>/dev/null \
    | grep -E '^android-[0-9]+$' | sed 's/android-//' | sort -n | tail -1)"
  if [ -z "$IJK_SDK_API" ]; then
    echo "No android-* platforms found under $ANDROID_SDK/platforms" >&2
    exit 1
  fi
fi
ANDROID_JAR="$ANDROID_SDK/platforms/android-$IJK_SDK_API/android.jar"
if [ ! -f "$ANDROID_JAR" ]; then
  echo "android.jar not found at $ANDROID_JAR" >&2
  exit 1
fi

export ANDROID_NDK ANDROID_SDK
export ANDROID_NDK_HOME="$ANDROID_NDK"
export PATH="$ANDROID_NDK/toolchains/llvm/prebuilt/$HOST_TAG/bin:$PATH"

echo "==> Configuration"
echo "    ijkplayer : $IJKPLAYER_REPO @ $IJKPLAYER_COMMIT"
echo "    archs     : $IJK_ARCHS"
echo "    ndk api   : $IJK_NDK_API"
echo "    sdk api   : $IJK_SDK_API"
echo "    ndk       : $ANDROID_NDK"
echo "    sdk       : $ANDROID_SDK"
echo "    build root: $IJK_BUILD_ROOT"

# ---------------------------------------------------------------------------
# 1. Checkout ijkplayer at the pinned commit
# ---------------------------------------------------------------------------
if [ -d "$IJK_BUILD_ROOT/.git" ]; then
  echo "==> Reusing existing checkout at $IJK_BUILD_ROOT"
  git -C "$IJK_BUILD_ROOT" fetch --tags --quiet
else
  echo "==> Cloning $IJKPLAYER_REPO into $IJK_BUILD_ROOT"
  mkdir -p "$(dirname "$IJK_BUILD_ROOT")"
  git clone --depth 1 --branch "$IJKPLAYER_COMMIT" "$IJKPLAYER_REPO" "$IJK_BUILD_ROOT" \
    || git clone "$IJKPLAYER_REPO" "$IJK_BUILD_ROOT"
fi
git -C "$IJK_BUILD_ROOT" checkout --quiet "$IJKPLAYER_COMMIT"

cd "$IJK_BUILD_ROOT"

# ---------------------------------------------------------------------------
# 2. Fetch ffmpeg + openssl sources
# ---------------------------------------------------------------------------
# NOTE: upstream init-android.sh only pulls FFmpeg (+ libyuv/soundtouch).
# OpenSSL must be initialized separately (init-android-openssl.sh); without it
# the ffmpeg build fails at link time because do-compile-ffmpeg.sh passes
# --enable-openssl and links against libssl/libcrypto.
echo "==> init-android.sh (ffmpeg sources)"
./init-android.sh

echo "==> init-android-openssl.sh (openssl sources)"
./init-android-openssl.sh

# ---------------------------------------------------------------------------
# 3. NDK/clang compatibility patches (idempotent, marked)
# ---------------------------------------------------------------------------
# k0.8.8-era build scripts point TOOLCHAIN at the removed gcc prebuilts
# (toolchains/<arch>-linux-android-4.9/prebuilt). Modern NDKs only ship the
# unified llvm prebuilt. Rewrite every such reference to the llvm path. The
# llvm toolchain is arch-independent, so this is safe for all target ABIs.
PATCH_MARK="# streamhub-ndk-patch"

# Reset every file we patch to its pristine upstream state first. The seds
# below are destructive/idempotent-hostile (a strip applied by an older
# revision of this pipeline must not survive into newer runs), so patching
# always starts from a clean slate. Outer-repo files and the per-arch
# openssl clones (inner repos) both carry local modifications.
echo "==> Restoring pristine upstream build scripts"
git -C "$IJK_BUILD_ROOT" checkout -- \
  android/contrib/tools/do-detect-env.sh \
  android/contrib/tools/do-compile-ffmpeg.sh \
  android/contrib/compile-ffmpeg.sh \
  android/contrib/tools/do-compile-openssl.sh \
  android/contrib/compile-openssl.sh \
  android/compile-ijk.sh 2>/dev/null || true
for d in "$IJK_BUILD_ROOT"/android/contrib/openssl-*; do
  [ -d "$d/.git" ] && git -C "$d" checkout -- Configure 2>/dev/null || true
done

apply_ndk_patch() {
  local file="$1"
  [ -f "$file" ] || return 0
  grep -q "$PATCH_MARK" "$file" && return 0
  echo "    patching $file"
  # Unify the gcc prebuilt path to the llvm prebuilt.
  LC_ALL=C sed -i.bak -E "s#toolchains/[^/]*-4\.9/prebuilt#toolchains/llvm/prebuilt#g" "$file"
  # Where the CC/CXX are derived from CROSS_PREFIX + gcc, switch to clang.
  LC_ALL=C sed -i.bak -E "s#(CROSS_PREFIX=.*)gcc#\1clang#g; s#(CROSS_PREFIX=.*)g\+\+#\1clang++#g" "$file"
  # Force the llvm clang as the compiler when a bare gcc would be selected.
  LC_ALL=C sed -i.bak -E "s#(--cc=)[^ ]*gcc#\1\$CC#g; s#(--cxx=)[^ ]*g\+\+#\1\$CXX#g" "$file"
  # The upstream NDK-version gate (do-detect-env.sh) only whitelists NDK
  # 11*-14*; extend it so modern NDKs (15-28) are accepted.
  if [ "$file" = "android/contrib/tools/do-detect-env.sh" ]; then
    LC_ALL=C sed -i.bak -E 's/11\*\|12\*\|13\*\|14\*/&|15*|16*|17*|18*|19*|20*|21*|22*|23*|24*|25*|26*|27*|28*/' "$file"
    LC_ALL=C sed -i.bak -E 's#toolchains/arm-linux-androideabi-4\.9#toolchains/llvm/prebuilt#' "$file"
  fi
  # OpenSSL's legacy android targets ("android", "android-armv7", ...) inject
  # -mandroid plus ANDROID_DEV include/lib paths from the pre-r19 NDK layout;
  # modern clang rejects -mandroid and ANDROID_DEV no longer exists. Strip
  # them — the API-21 clang wrappers already carry the correct --sysroot.
  case "$file" in
    android/contrib/openssl-*/Configure)
      # LC_ALL=C: upstream Configure contains non-UTF8 bytes and BSD sed
      # aborts on them otherwise. The ANDROID_DEV tokens appear with an
      # escaped dollar in the config strings (\$), hence the loose match.
      # NOTE: do NOT strip \${armv4_asm} here — its expansion contains
      # colon-separated sub-fields and removing it wholesale shifts every
      # later config field left (observed: dlfcn parsed as BN_ASM). The
      # armv7a assembly is disabled at build time instead, via
      # COMMON_FF_CFG_FLAGS="no-asm" on the compile-openssl.sh invocation.
      LC_ALL=C sed -i.bak -E 's/ -mandroid//g; s# -I[^ ]*ANDROID_DEV[^ ]*##g; s# -B[^ ]*ANDROID_DEV[^ ]*##g' "$file"
      ;;
  esac
  # armv7a openssl: disable the hand-written assembly at the source. The
  # gcc-era armv4 asm neither assembles under clang's integrated assembler
  # (ADRL) nor NDK r21 GNU as (conditional ldrb spellings). COMMON_FF_CFG_FLAGS
  # cannot be used — do-compile-openssl.sh resets it internally — so the flag
  # is appended right where the platform config is selected.
  if [ "$file" = "android/contrib/tools/do-compile-openssl.sh" ]; then
    LC_ALL=C sed -i.bak '/FF_PLATFORM_CFG_FLAGS="android-armv7"$/a\
    FF_CFG_FLAGS="$FF_CFG_FLAGS no-asm -fPIC" '"$PATCH_MARK" "$file"
  fi
  # armv7a ffmpeg: the rgb2yuv NEON macros use instructions clang's
  # integrated assembler rejects; route assembly through GNU as.
  if [ "$file" = "android/contrib/tools/do-compile-ffmpeg.sh" ]; then
    LC_ALL=C sed -i.bak '/-mfloat-abi=softfp -mthumb"$/a\
    FF_EXTRA_CFLAGS="$FF_EXTRA_CFLAGS -fno-integrated-as" '"$PATCH_MARK" "$file"
  fi
  printf '\n%s applied\n' "$PATCH_MARK" >> "$file"
}
for f in \
  android/contrib/tools/do-detect-env.sh \
  android/contrib/tools/do-compile-ffmpeg.sh \
  android/contrib/compile-ffmpeg.sh \
  android/contrib/tools/do-compile-openssl.sh \
  android/contrib/compile-openssl.sh \
  android/compile-ijk.sh \
  android/ijkplayer/ijkplayer-arm64/build.gradle \
  android/ijkplayer/ijkplayer-armv7a/build.gradle ; do
  apply_ndk_patch "$f"
done
# The per-arch openssl Configure clones are pulled by init-android-openssl.sh;
# patch each one that exists (glob expanded here, not in the function).
for configure_file in "$IJK_BUILD_ROOT"/android/contrib/openssl-*/Configure; do
  [ -f "$configure_file" ] || continue
  apply_ndk_patch "${configure_file#"$IJK_BUILD_ROOT"/}"
done

# ffmpeg-armv7a only: compile out the rgb2yuv NEON objects. They use FPA-era
# `.dn dN.lane[x]` directives that neither modern clang nor GNU as accept
# (upstream FFmpeg rewrote this area years later). Removing the two objects
# plus every reference leaves an all-C fallback for RGBA->NV12; all other
# NEON paths (yuv2rgb, hscale) are unaffected.
RGBX_FILES="android/contrib/ffmpeg-armv7a/libswscale/arm/Makefile \
android/contrib/ffmpeg-armv7a/libswscale/arm/swscale_unscaled.c"
git -C "$IJK_BUILD_ROOT" checkout -- $RGBX_FILES 2>/dev/null || true
LC_ALL=C sed -i.bak '/^NEON-OBJS   += arm\/rgb2yuv_neon_/d' \
  "$IJK_BUILD_ROOT/android/contrib/ffmpeg-armv7a/libswscale/arm/Makefile"
LC_ALL=C sed -i.bak -E '/^extern void rgbx_to_nv12_neon_(16|32)/,/coeff_tbl\[9\]\);/d; /^static int rgbx_to_nv12_neon_(16|32)_wrapper/,/^}/d' \
  "$IJK_BUILD_ROOT/android/contrib/ffmpeg-armv7a/libswscale/arm/swscale_unscaled.c"
LC_ALL=C sed -i.bak '/c->srcFormat == AV_PIX_FMT_RGBA/,/}/d' \
  "$IJK_BUILD_ROOT/android/contrib/ffmpeg-armv7a/libswscale/arm/swscale_unscaled.c"
echo "    patched ffmpeg-armv7a rgb2yuv NEON compile-out"

# Ensure the per-arch ndk-build invocation uses the clang toolchain. ijk's
# compile-ijk.sh derives TOOLCHAIN from ANDROID_NDK; the sed above already
# retargets it.
# Patch APP_STL for modern NDK compatibility (stlport_static is removed)
# Remove -ffast-math because it breaks isnan() and NAN in modern clang.
find "$IJK_BUILD_ROOT" -type f -name "Application.mk" -exec \
  sed -i.bak -e 's/APP_STL := stlport_static/APP_STL := c++_static/g' -e 's/-ffast-math//g' {} +

# Remove isnan hack from ff_ffplay.c that calls undeclared isnanf
find "$IJK_BUILD_ROOT" -type f -name "ff_ffplay.c" -exec sh -c '
for f; do
  git -C "$(dirname "$f")" checkout "$(basename "$f")" 2>/dev/null || true
  sed -i.bak -e "s/#undef isnan//g" -e "s/#define isnan(x) (isnan((double)(x)) || isnanf((float)(x)))//g" "$f"
done
' sh {} +

# Fix int conversion error in newer clang
find "$IJK_BUILD_ROOT" -type f -name "ffpipeline_android.c" -exec \
  sed -i.bak 's/int                       ret = NULL;/int                       ret = 0;/g' {} +

# Fix std=c99 flag for C++ files in Android.mk
find "$IJK_BUILD_ROOT" -type f -name "Android.mk" -exec \
  sed -i.bak 's/LOCAL_CFLAGS += -std=c99/LOCAL_CONLYFLAGS += -std=c99/g' {} +

# Fix missing ANativeWindow headers in ijksdl_egl.c
find "$IJK_BUILD_ROOT" -type f -name "ijksdl_egl.c" -exec \
  sed -i.bak '/#include "ijksdl_egl.h"/a\
#include <android/native_window.h>
' {} +

# Fail on error for compile-ijk.sh so build does not silently ignore failures
find "$IJK_BUILD_ROOT" -type f -name "compile-ijk.sh" -exec \
  sed -i.bak -e '1a\
set -e' {} +

# ---------------------------------------------------------------------------
# 3b. Pre-provision standalone-style toolchain trees (NDK r19+)
# ---------------------------------------------------------------------------
# Both do-compile-{openssl,ffmpeg}.sh build their cross toolchain through
# NDK's legacy make-standalone-toolchain.sh gated by a touch file at
#   <contrib>/build/<name>/toolchain/touch
# That script no longer accepts the GCC-era --toolchain names on modern NDKs
# ("ERROR: Failed to create toolchain."). Rather than rewriting upstream
# control flow, we pre-create equivalent trees with the supported
# make_standalone_toolchain.py (same bin/<triple>-gcc -> clang layout) and
# drop the touch files so the upstream branch is skipped entirely.
echo "==> Provisioning standalone toolchains"
TC_API="$IJK_NDK_API"
for arch in $IJK_ARCHS; do
  case "$arch" in
    armv5|armv7a) py_arch="arm" ;;
    *)            py_arch="$arch" ;;
  esac
  tc_cache="$IJK_BUILD_ROOT/.streamhub-toolchains/$py_arch-$TC_API"
  if [ ! -x "$tc_cache/bin/clang" ]; then
    rm -rf "$tc_cache"
    # No mkdir here: the installer refuses a pre-existing directory.
    # macOS ships no bare `python`, so bypass the script's shebang.
    python3 "$ANDROID_NDK/build/tools/make_standalone_toolchain.py" \
      --arch="$py_arch" --api="$TC_API" --install-dir="$tc_cache"
  fi
  for name in openssl-"$arch" ffmpeg-"$arch"; do
    tc_dir="$IJK_BUILD_ROOT/android/contrib/build/$name/toolchain"
    mkdir -p "$tc_dir"
    # Copy rather than symlink: the contrib clean steps may rm -rf the tree.
    rm -rf "$tc_dir" && cp -R "$tc_cache" "$tc_dir"
    touch "$tc_dir/touch"
    echo "    provisioned $name -> $(basename "$tc_cache")"
  done
done

# The r21e-era GNU host binutils abort on recent macOS hosts (typed operator
# new before libcxx static init, macOS 26 dyld). Replace the archive tools
# with the universal LLVM equivalents from any installed newer NDK; they are
# drop-in compatible (same archive format, cross-arch agnostic). Detection is
# automatic across common SDK locations.
LLVM_BIN=""
for cand in \
  "${ANDROID_NDK_HOME:-}/../../28.2.13676358/toolchains/llvm/prebuilt/$HOST_TAG/bin" \
  "$ANDROID_SDK/ndk/28.2.13676358/toolchains/llvm/prebuilt/$HOST_TAG/bin" \
  "$ANDROID_SDK/ndk/27.0.12077973/toolchains/llvm/prebuilt/$HOST_TAG/bin" \
  "$ANDROID_SDK/ndk/26.3.11579264/toolchains/llvm/prebuilt/$HOST_TAG/bin" ; do
  if [ -x "$cand/llvm-ar" ]; then LLVM_BIN="$cand"; break; fi
done
if [ -n "$LLVM_BIN" ]; then
  echo "==> Swapping legacy host binutils for $LLVM_BIN"
  # Patch BOTH the caches and every provisioned copy: the contrib scripts put
  # their copy's bin/ on PATH.
  local_bin_dirs=(
    "$IJK_BUILD_ROOT"/.streamhub-toolchains/*/bin
    "$IJK_BUILD_ROOT"/android/contrib/build/*/toolchain/bin
  )
  for tc in "${local_bin_dirs[@]}"; do
    for tool in ar ranlib nm strip; do
      if [ -x "$LLVM_BIN/llvm-$tool" ]; then
        for wrapper in "$tc"/*-"$tool"; do
          [ -e "$wrapper" ] || continue
          ln -sf "$LLVM_BIN/llvm-$tool" "$wrapper"
        done
      fi
    done
  done
fi

# ---------------------------------------------------------------------------
# 4. Build ffmpeg + openssl per arch
# ---------------------------------------------------------------------------
echo "==> Building contrib (openssl + ffmpeg) for: $IJK_ARCHS"
cd "$IJK_BUILD_ROOT/android/contrib"
for arch in $IJK_ARCHS; do
  echo "---- openssl/$arch ----"
  if [ "$arch" = "armv7a" ]; then
    # no-asm: the gcc-era armv4 assembly neither assembles under clang's
    # integrated assembler (ADRL) nor NDK r21 GNU as (conditional ldrb).
    # Handshake-only impact; acceptable for the evaluation build.
    COMMON_FF_CFG_FLAGS="no-asm" ./compile-openssl.sh "$arch"
  else
    ./compile-openssl.sh "$arch"
  fi
  echo "---- ffmpeg/$arch ----"
  ./compile-ffmpeg.sh "$arch"
done

# ---------------------------------------------------------------------------
# 5. Build ijkplayer native layers per arch
# ---------------------------------------------------------------------------
echo "==> Building ijkplayer native for: $IJK_ARCHS"
cd "$IJK_BUILD_ROOT/android"
for arch in $IJK_ARCHS; do
  echo "---- ijkplayer/$arch ----"
  ./compile-ijk.sh "$arch"
done

# ---------------------------------------------------------------------------
# 6. Package the ijkplayer-java AAR manually
# ---------------------------------------------------------------------------
# The in-tree Gradle build does not run under current JDKs, so we compile the
# Java sources against android.jar and zip a minimal AAR (classes.jar +
# AndroidManifest.xml). ijkplayer-java has no compiled resources, so this is
# sufficient for the app's `implementation(files(...))` consumption.
echo "==> Packaging ijkplayer-java AAR"
JAVA_SRC="$IJK_BUILD_ROOT/android/ijkplayer/ijkplayer-java/src/main/java"
MANIFEST_SRC="$IJK_BUILD_ROOT/android/ijkplayer/ijkplayer-java/src/main/AndroidManifest.xml"
OUT="$IJK_BUILD_ROOT/android/ijkplayer/ijkplayer-java/build"
AAR_DIR="$OUT/aar"
mkdir -p "$AAR_DIR" "$OUT/classes"

# Collect every .java source (core player + misc helpers).
# Portable (bash 3.2 on macOS ships without mapfile/process substitution).
JAVA_FILES=()
while IFS= read -r f; do JAVA_FILES+=("$f"); done < <(find "$JAVA_SRC" -name '*.java')
if [ "${#JAVA_FILES[@]}" -eq 0 ]; then
  echo "No Java sources found under $JAVA_SRC" >&2
  exit 1
fi

javac -d "$OUT/classes" -cp "$ANDROID_JAR" "${JAVA_FILES[@]}"
jar cf "$AAR_DIR/classes.jar" -C "$OUT/classes" .

# Manifest: reuse the in-tree one if present, otherwise emit a minimal package
# declaration. The Java package is tv.danmaku.ijk.media.player.
if [ -f "$MANIFEST_SRC" ]; then
  cp "$MANIFEST_SRC" "$AAR_DIR/AndroidManifest.xml"
else
  cat > "$AAR_DIR/AndroidManifest.xml" <<'XML'
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="tv.danmaku.ijk.media.player">
</manifest>
XML
fi

# An empty R.txt keeps AAR consumers happy.
: > "$AAR_DIR/R.txt"

( cd "$AAR_DIR" && zip -q -r ../ijkplayer-java-release.aar . )
AAR_OUT="$OUT/ijkplayer-java-release.aar"
if [ ! -f "$AAR_OUT" ]; then
  echo "Failed to produce $AAR_OUT" >&2
  exit 1
fi
echo "    wrote $AAR_OUT"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo
echo "==> Build complete"
echo "    AAR : $AAR_OUT"
for arch in $IJK_ARCHS; do
  abi="armeabi-v7a"; [ "$arch" = "arm64" ] && abi="arm64-v8a"
  echo "    so  : android/ijkplayer/ijkplayer-$arch/src/main/libs/$abi/lib{ijkplayer,ijksdl,ijkffmpeg}.so"
done
echo
echo "Next: tools/ijkplayer/vendor.sh"
