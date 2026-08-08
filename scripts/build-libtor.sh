#!/usr/bin/env bash
# Build libtor.so for Android from source (OpenSSL, libevent, zstd, xz, Tor).
# No republish from foreign CI — clones pinned upstreams and runs external/Makefile.
#
# Usage:
#   ANDROID_NDK_HOME=/path/to/ndk ./scripts/build-libtor.sh
#   ABIS="arm64 x86_64" ENABLE_MTE=1 ./scripts/build-libtor.sh
#
# Outputs:
#   dist/tor/libtor-arm64-v8a.so
#   dist/tor/libtor-x86_64.so
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXTERNAL="${ROOT}/external"
DIST_TOR="${ROOT}/dist/tor"
mkdir -p "$DIST_TOR" "$EXTERNAL"

ANDROID_NDK_HOME="${ANDROID_NDK_HOME:-${ANDROID_NDK:-}}"
if [[ -z "${ANDROID_NDK_HOME}" ]]; then
  if [[ -d "${ANDROID_HOME:-}/ndk" ]]; then
    ANDROID_NDK_HOME="$(ls -d "${ANDROID_HOME}/ndk"/* | sort -V | tail -1)"
  elif [[ -d "${HOME}/Android/Sdk/ndk" ]]; then
    ANDROID_NDK_HOME="$(ls -d "${HOME}/Android/Sdk/ndk"/* | sort -V | tail -1)"
  fi
fi
if [[ -z "${ANDROID_NDK_HOME}" || ! -d "${ANDROID_NDK_HOME}" ]]; then
  echo "ERROR: set ANDROID_NDK_HOME (NDK r28+ recommended)." >&2
  exit 1
fi
export ANDROID_NDK_HOME

# Makefile APP_ABI values (arm64 not arm64-v8a).
ABIS="${ABIS:-arm64 x86_64}"
ENABLE_MTE="${ENABLE_MTE:-1}"

# Pinned deps — keep in sync with .gitlab-ci.yml
OPENSSL_REF="${OPENSSL_REF:-openssl-3.6.3}"
LIBEVENT_REF="${LIBEVENT_REF:-release-2.1.12-stable}"
ZSTD_REF="${ZSTD_REF:-v1.4.9}"
XZ_REF="${XZ_REF:-v5.2.4}"
TOR_REF="${TOR_REF:-prod-0.4.9}"
TOR_REPO="${TOR_REPO:-https://gitlab.torproject.org/Gedsh/tor.git}"

clone_or_update() {
  local url="$1" dest="$2" ref="$3"
  if [[ -d "$dest/.git" ]]; then
    echo "Updating $(basename "$dest") @$ref ..."
    git -C "$dest" fetch --depth 1 origin "$ref" || git -C "$dest" fetch --depth 1 origin "+refs/heads/$ref:refs/remotes/origin/$ref" || true
    git -C "$dest" checkout -f "$ref" 2>/dev/null \
      || git -C "$dest" checkout -f "origin/$ref" 2>/dev/null \
      || git -C "$dest" checkout -f FETCH_HEAD
  else
    echo "Cloning $(basename "$dest") @$ref ..."
    rm -rf "$dest"
    git clone --depth 1 --single-branch --branch "$ref" "$url" "$dest"
  fi
}

echo "NDK=$ANDROID_NDK_HOME"
echo "ABIS=$ABIS ENABLE_MTE=$ENABLE_MTE"

cd "$EXTERNAL"
clone_or_update "https://github.com/openssl/openssl.git" "$EXTERNAL/openssl" "$OPENSSL_REF"
clone_or_update "https://github.com/libevent/libevent.git" "$EXTERNAL/libevent" "$LIBEVENT_REF"
clone_or_update "https://github.com/facebook/zstd.git" "$EXTERNAL/zstd" "$ZSTD_REF"
clone_or_update "https://git.tukaani.org/xz.git" "$EXTERNAL/xz" "$XZ_REF"
clone_or_update "$TOR_REPO" "$EXTERNAL/tor" "$TOR_REF"

abi_to_release_name() {
  case "$1" in
    arm64|arm64-v8a) echo "arm64-v8a" ;;
    x86_64) echo "x86_64" ;;
    *) echo "$1" ;;
  esac
}

makefile_abi() {
  case "$1" in
    arm64-v8a) echo "arm64" ;;
    *) echo "$1" ;;
  esac
}

for abi_in in $ABIS; do
  abi="$(makefile_abi "$abi_in")"
  rel="$(abi_to_release_name "$abi")"
  echo "======== Building libtor for APP_ABI=$abi (release=$rel) ========"
  mte_flag=0
  if [[ "$abi" == "arm64" && "$ENABLE_MTE" == "1" ]]; then
    mte_flag=1
  fi
  (
    cd "$EXTERNAL"
    make clean || true
    # MTE sanitizer requires API 31+; keep API 21 when MTE is off.
    platform=21
    if [[ "$mte_flag" == "1" ]]; then
      platform=31
    fi
    make \
      APP_ABI="$abi" \
      NDK_PLATFORM_LEVEL="$platform" \
      NDK_BIT=64 \
      ENABLE_MTE="$mte_flag" \
      ANDROID_NDK_HOME="$ANDROID_NDK_HOME"
  )
  src="${ROOT}/tor-android-binary/src/main/libs/${abi}/libtor.so"
  if [[ ! -f "$src" ]]; then
    echo "ERROR: expected $src after make" >&2
    exit 1
  fi
  cp -f "$src" "${DIST_TOR}/libtor-${rel}.so"
  ls -lh "${DIST_TOR}/libtor-${rel}.so"
done

echo "OK: built $(ls -1 "$DIST_TOR"/libtor-*.so | tr '\n' ' ')"
