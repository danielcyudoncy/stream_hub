#!/usr/bin/env bash
#
# StreamHub Pro - Phase 3 playback-engine evaluation vendoring.
#
# Copies self-built ijkplayer artifacts from a completed
# tools/streamhub-build.sh run into the Android host application:
#   - ijkplayer-java-release.aar -> android/app/libs/
#   - per-ABI libijkplayer.so / libijksdl.so / libijkffmpeg.so
#     -> android/app/src/main/jniLibs/<abi>/
#
# The build tree location defaults to ../stream_hub_tmp_ijk/ijkplayer
# relative to this repository; override with IJKPLAYER_BUILD_ROOT.
#
# Usage: tools/ijkplayer/vendor.sh [path-to-ijkplayer-build-tree]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="${1:-${IJKPLAYER_BUILD_ROOT:-$REPO_ROOT/../stream_hub_tmp_ijk/ijkplayer}}"

AAR_SRC="$SRC/android/ijkplayer/ijkplayer-java/build/ijkplayer-java-release.aar"
[ -f "$AAR_SRC" ] || { echo "AAR not found: $AAR_SRC — run the ijkplayer build first"; exit 1; }

LIBS_DIR="$REPO_ROOT/android/app/libs"
JNI_DIR="$REPO_ROOT/android/app/src/main/jniLibs"
mkdir -p "$LIBS_DIR"

cp "$AAR_SRC" "$LIBS_DIR/"
echo "vendored $LIBS_DIR/ijkplayer-java-release.aar"

copy_abi() {
    local arch="$1" abi="$2"
    local module="$SRC/android/ijkplayer/ijkplayer-$arch/src/main/libs/$abi"
    [ -d "$module" ] || { echo "WARN: no native libs for $abi ($module)"; return 0; }
    mkdir -p "$JNI_DIR/$abi"
    # libijkffmpeg.so lives in the contrib output until ndk-build merges it;
    # fall back to the contrib path when absent from the module libs dir.
    for so in "$module"/lib*.so; do
        cp "$so" "$JNI_DIR/$abi/"
    done
    if [ ! -f "$JNI_DIR/$abi/libijkffmpeg.so" ]; then
        ffmpeg_so="$SRC/android/contrib/build/ffmpeg-$arch/output/libijkffmpeg.so"
        if [ -f "$ffmpeg_so" ]; then
            cp "$ffmpeg_so" "$JNI_DIR/$abi/"
        fi
    fi
    echo "vendored $JNI_DIR/$abi/: $(ls "$JNI_DIR/$abi" | tr '\n' ' ')"
}

copy_abi arm64 arm64-v8a
copy_abi armv7a armeabi-v7a

echo "Vendoring complete."
