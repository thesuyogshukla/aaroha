#!/usr/bin/env bash
# Builds the native audio core for this Mac, for the fixture runner.
# Output: build/native-host/libaaroha_audio.dylib
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"

# Use cmake/ninja from PATH, or fall back to the Android SDK's copies.
cmake_bin="$(command -v cmake || true)"
if [[ -z "$cmake_bin" ]]; then
  sdk="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
  cmake_bin="$(ls -d "$sdk"/cmake/*/bin/cmake 2>/dev/null | sort -V | tail -1)"
fi
if [[ -z "$cmake_bin" ]]; then
  echo "cmake not found: install it or the Android SDK CMake package" >&2
  exit 1
fi
ninja_bin="$(command -v ninja || echo "$(dirname "$cmake_bin")/ninja")"

"$cmake_bin" -S "$root/packages/aaroha_audio/src" -B "$root/build/native-host" \
  -G Ninja -DCMAKE_MAKE_PROGRAM="$ninja_bin" -DCMAKE_BUILD_TYPE=Release
"$cmake_bin" --build "$root/build/native-host"
