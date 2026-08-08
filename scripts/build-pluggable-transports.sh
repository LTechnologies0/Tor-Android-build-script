#!/usr/bin/env bash
# Build Tor pluggable transports for Android (OnionVPN / LTechnologies0).
#
# Outputs (per ABI):
#   dist/<abi>/libLyrebird.so   — meek_lite,obfs2,obfs3,obfs4,scramblesuit,webtunnel,snowflake
#   dist/<abi>/libConjure.so    — conjure (arm64 + x86_64 when Go target exists)
#
# Build flags follow Tor Browser Android + Android 16 KB page-size guidance:
#   https://developer.android.com/guide/practices/page-sizes
#   -Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384
#   Go 1.23+ Android: -checklinkname=0 (wlynxg/anet)
#
# Usage:
#   ANDROID_NDK_HOME=/path/to/ndk ./scripts/build-pluggable-transports.sh
#   ABIS="arm64-v8a x86_64" ./scripts/build-pluggable-transports.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=load-versions.sh
. "${ROOT}/scripts/load-versions.sh"

DIST="${ROOT}/dist/pts"
WORKDIR="${TMPDIR:-/tmp}/ltech-pt-build"
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
  echo "ERROR: set ANDROID_NDK_HOME to an NDK install (r27+ recommended, r28+ ideal)." >&2
  exit 1
fi

API_LEVEL="${API_LEVEL:-21}"
ABIS="${ABIS:-arm64-v8a x86_64 armeabi-v7a}"

HOST_TAG="$(uname -s | tr '[:upper:]' '[:lower:]')-x86_64"
TOOLCHAIN="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/${HOST_TAG}"
if [[ ! -d "$TOOLCHAIN" ]]; then
  echo "ERROR: NDK llvm toolchain missing at $TOOLCHAIN" >&2
  exit 1
fi
export PATH="${TOOLCHAIN}/bin:${PATH}"

if ! command -v go >/dev/null 2>&1; then
  echo "ERROR: go toolchain required on PATH" >&2
  exit 1
fi

GO_VERSION="$(go env GOVERSION || true)"
echo "NDK=$ANDROID_NDK_HOME"
echo "Go=$GO_VERSION"
echo "ABIS=$ABIS"
echo "lyrebird@$LYREBIRD_REF  conjure@$CONJURE_REF"

clone_or_update() {
  local url="$1" dest="$2" ref="$3"
  if [[ -d "$dest/.git" ]]; then
    git -C "$dest" fetch --depth 1 origin "$ref" || git -C "$dest" fetch --depth 1 origin
    git -C "$dest" checkout -f "$ref" 2>/dev/null \
      || git -C "$dest" checkout -f FETCH_HEAD 2>/dev/null \
      || git -C "$dest" checkout -f "$ref"
  else
    rm -rf "$dest"
    # Tags/branches: shallow clone. Full SHA: clone then fetch SHA.
    if [[ "$ref" =~ ^[0-9a-f]{40}$ ]]; then
      git clone --filter=blob:none "$url" "$dest"
      git -C "$dest" fetch --depth 1 origin "$ref"
      git -C "$dest" checkout -f "$ref"
    else
      git clone --depth 1 --branch "$ref" "$url" "$dest" \
        || { git clone --depth 1 "$url" "$dest"; git -C "$dest" checkout -f "$ref"; }
    fi
  fi
}

clone_or_update "$LYREBIRD_REPO" "$WORKDIR/lyrebird" "$LYREBIRD_REF"
clone_or_update "$CONJURE_REPO" "$WORKDIR/conjure" "$CONJURE_REF"

# Map Android ABI → Go GOARCH + clang triple prefix
abi_to_goarch() {
  case "$1" in
    arm64-v8a|arm64) echo arm64 ;;
    armeabi-v7a|armeabi) echo arm ;;
    x86_64) echo amd64 ;;
    x86) echo 386 ;;
    *) echo "unsupported abi $1" >&2; return 1 ;;
  esac
}

abi_to_clang() {
  case "$1" in
    arm64-v8a|arm64) echo "aarch64-linux-android${API_LEVEL}-clang" ;;
    armeabi-v7a|armeabi) echo "armv7a-linux-androideabi${API_LEVEL}-clang" ;;
    x86_64) echo "x86_64-linux-android${API_LEVEL}-clang" ;;
    x86) echo "i686-linux-android${API_LEVEL}-clang" ;;
    *) return 1 ;;
  esac
}

PAGE_LDFLAGS="-Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384"

build_one() {
  local abi="$1" project="$2" pkg="$3" outname="$4"
  local goarch clangcc outdir
  goarch="$(abi_to_goarch "$abi")"
  clangcc="$(abi_to_clang "$abi")"
  outdir="${DIST}/${abi}"
  mkdir -p "$outdir"

  if [[ ! -x "${TOOLCHAIN}/bin/${clangcc}" ]]; then
    echo "SKIP $outname for $abi — clang $clangcc missing"
    return 0
  fi

  echo "Building $outname ($abi / GOARCH=$goarch)..."
  (
    cd "$WORKDIR/$project"
    go mod download

    export CGO_ENABLED=1
    export GOOS=android
    export GOARCH="$goarch"
    export CC="${TOOLCHAIN}/bin/${clangcc}"
    export CGO_CFLAGS="-O2 -fPIC"
    export CGO_LDFLAGS="${PAGE_LDFLAGS}"
    # Go 1.23+ Android needs -checklinkname=0 for wlynxg/anet (Tor Browser #41387)
    # Pin PIE + 16KB via extldflags (Android-standalone Go PT).
    go build -buildmode=pie -trimpath \
      -ldflags "-s -w -checklinkname=0 -extldflags '${PAGE_LDFLAGS}'" \
      -o "${outdir}/${outname}" "$pkg"
  )

  local bytes
  bytes="$(wc -c <"${outdir}/${outname}")"
  if [[ "$bytes" -lt 1000000 ]]; then
    echo "ERROR: ${outdir}/${outname} too small ($bytes bytes)" >&2
    exit 1
  fi
  chmod +x "${outdir}/${outname}"
  echo "  OK ${outdir}/${outname} ($bytes bytes)"
}

verify_align() {
  local so="$1"
  local objdump="${TOOLCHAIN}/bin/llvm-objdump"
  [[ -x "$objdump" ]] || return 0
  if "$objdump" -p "$so" | grep -E 'LOAD.*align 2\*\*1[2-3]' >/dev/null; then
    echo "WARN: $so still has <16KB LOAD align (check objdump):" >&2
    "$objdump" -p "$so" | grep LOAD | head -4 >&2 || true
  else
    echo "  align-ok $(basename "$so")"
  fi
}

for abi in $ABIS; do
  build_one "$abi" lyrebird ./cmd/lyrebird libLyrebird.so
  build_one "$abi" conjure ./client libConjure.so
done

echo
echo "Artifacts under $DIST:"
find "$DIST" -type f -name 'lib*.so' -printf '  %p (%s bytes)\n' | sort

for so in "$DIST"/*/lib*.so; do
  [[ -f "$so" ]] || continue
  verify_align "$so"
done

chmod +x "${ROOT}/scripts/verify-android-standalone.sh"
"${ROOT}/scripts/verify-android-standalone.sh" --dir "$DIST"

# Write ClientTransportPlugin cheat-sheet for OnionVPN / docs
cat >"$DIST/CLIENT_TRANSPORT_PLUGIN.txt" <<'EOF'
# Tor Browser Android–compatible ClientTransportPlugin lines
# Replace ${PT_DIR} with absolute nativeLibraryDir on device.

ClientTransportPlugin meek_lite,obfs2,obfs3,obfs4,scramblesuit,webtunnel exec ${PT_DIR}/libLyrebird.so
ClientTransportPlugin snowflake exec ${PT_DIR}/libLyrebird.so
ClientTransportPlugin conjure exec ${PT_DIR}/libConjure.so -registerURL https://registration.refraction.network/api
EOF

echo "Done."
