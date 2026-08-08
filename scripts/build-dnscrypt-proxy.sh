#!/usr/bin/env bash
# Build libdnscrypt-proxy.so for Android (same packaging convention as Lyrebird).
#
# Usage:
#   ANDROID_NDK_HOME=/path/to/ndk ./scripts/build-dnscrypt-proxy.sh
#   ABIS="arm64-v8a x86_64" ./scripts/build-dnscrypt-proxy.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=load-versions.sh
. "${ROOT}/scripts/load-versions.sh"

: "${DNSCRYPT_REF:=$(grep -E '^dnscrypt\.ref=' "${ROOT}/versions.properties" | cut -d= -f2- | tr -d '[:space:]')}"
: "${DNSCRYPT_REPO:=$(grep -E '^dnscrypt\.repo=' "${ROOT}/versions.properties" | cut -d= -f2- | tr -d '[:space:]')}"

DIST="${ROOT}/dist/dnscrypt"
WORKDIR="${TMPDIR:-/tmp}/ltech-dnscrypt-build"
mkdir -p "$DIST" "$WORKDIR"

ANDROID_NDK_HOME="${ANDROID_NDK_HOME:-${ANDROID_NDK:-}}"
if [[ -z "${ANDROID_NDK_HOME}" ]]; then
  if [[ -d "${ANDROID_HOME:-}/ndk" ]]; then
    ANDROID_NDK_HOME="$(ls -d "${ANDROID_HOME}/ndk"/* | sort -V | tail -1)"
  elif [[ -d "${HOME}/Android/Sdk/ndk" ]]; then
    ANDROID_NDK_HOME="$(ls -d "${HOME}/Android/Sdk/ndk"/* | sort -V | tail -1)"
  fi
fi
if [[ -z "${ANDROID_NDK_HOME}" || ! -d "${ANDROID_NDK_HOME}" ]]; then
  echo "ERROR: set ANDROID_NDK_HOME" >&2
  exit 1
fi

API_LEVEL="${API_LEVEL:-21}"
ABIS="${ABIS:-arm64-v8a x86_64}"
HOST_TAG="$(uname -s | tr '[:upper:]' '[:lower:]')-x86_64"
TOOLCHAIN="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/${HOST_TAG}"
export PATH="${TOOLCHAIN}/bin:${PATH}"
command -v go >/dev/null || { echo "ERROR: go required" >&2; exit 1; }

PAGE_LDFLAGS="-Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384"

echo "dnscrypt-proxy @$DNSCRYPT_REF from $DNSCRYPT_REPO"
rm -rf "$WORKDIR/dnscrypt-proxy"
git clone --depth 1 --branch "$DNSCRYPT_REF" "$DNSCRYPT_REPO" "$WORKDIR/dnscrypt-proxy" \
  || git clone --depth 1 "$DNSCRYPT_REPO" "$WORKDIR/dnscrypt-proxy"

abi_to_goarch() {
  case "$1" in
    arm64-v8a|arm64) echo arm64 ;;
    x86_64) echo amd64 ;;
    *) echo "unsupported $1" >&2; return 1 ;;
  esac
}
abi_to_clang() {
  case "$1" in
    arm64-v8a|arm64) echo "aarch64-linux-android${API_LEVEL}-clang" ;;
    x86_64) echo "x86_64-linux-android${API_LEVEL}-clang" ;;
    *) return 1 ;;
  esac
}

for abi in $ABIS; do
  goarch="$(abi_to_goarch "$abi")"
  clangcc="$(abi_to_clang "$abi")"
  outdir="${DIST}/${abi}"
  mkdir -p "$outdir"
  echo "Building libdnscrypt-proxy.so ($abi)..."
  (
    cd "$WORKDIR/dnscrypt-proxy/dnscrypt-proxy"
    go mod download
    export CGO_ENABLED=1 GOOS=android GOARCH="$goarch"
    export CC="${TOOLCHAIN}/bin/${clangcc}"
    export CGO_CFLAGS="-O2 -fPIC"
    export CGO_LDFLAGS="${PAGE_LDFLAGS}"
    go build -buildmode=pie -trimpath \
      -ldflags "-s -w -checklinkname=0 -extldflags '${PAGE_LDFLAGS}'" \
      -o "${outdir}/libdnscrypt-proxy.so" .
  )
  ls -lh "${outdir}/libdnscrypt-proxy.so"
done

chmod +x "${ROOT}/scripts/verify-android-standalone.sh"
"${ROOT}/scripts/verify-android-standalone.sh" --dir "$DIST"
echo "OK: DNSCrypt under $DIST"
