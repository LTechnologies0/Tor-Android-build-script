#!/usr/bin/env bash
# Build (or reuse) release assets and publish a GitHub Release for OnionVPN.
#
# libtor is built from source via scripts/build-libtor.sh (never downloaded from
# foreign CI). Pluggable transports are built when ANDROID_NDK_HOME + go exist.
#
# Usage:
#   ANDROID_NDK_HOME=/path/to/ndk ./scripts/publish-github-release.sh [tag]
# Default tag: tor-0.4.9.11-dev
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TAG="${1:-tor-0.4.9.11-dev}"
TMP="${TMPDIR:-/tmp}/ltech-tor-android-publish"
mkdir -p "$TMP/release"

REPO="${GITHUB_REPOSITORY:-LTechnologies0/Tor-Android-build-script}"

if [[ -z "${ANDROID_NDK_HOME:-}" ]]; then
  echo "ERROR: ANDROID_NDK_HOME required. This script no longer republishes libtor from Gedsh CI." >&2
  echo "  export ANDROID_NDK_HOME=/path/to/ndk" >&2
  echo "  ./scripts/build-libtor.sh && ./scripts/publish-github-release.sh $TAG" >&2
  exit 1
fi

echo "Building libtor from source → $REPO@$TAG ..."
chmod +x "$ROOT/scripts/build-libtor.sh"
ABIS="${ABIS:-arm64 x86_64}" ENABLE_MTE="${ENABLE_MTE:-1}" "$ROOT/scripts/build-libtor.sh"
cp -f "$ROOT"/dist/tor/libtor-*.so "$TMP/release/"

if command -v go >/dev/null 2>&1; then
  echo "Building pluggable transports (16 KB page size)..."
  chmod +x "$ROOT/scripts/build-pluggable-transports.sh"
  ABIS="${PT_ABIS:-arm64-v8a x86_64}" "$ROOT/scripts/build-pluggable-transports.sh"
  for abi in arm64-v8a x86_64; do
    [[ -f "$ROOT/dist/pts/$abi/libLyrebird.so" ]] && \
      cp -f "$ROOT/dist/pts/$abi/libLyrebird.so" "$TMP/release/libLyrebird-${abi}.so"
    [[ -f "$ROOT/dist/pts/$abi/libConjure.so" ]] && \
      cp -f "$ROOT/dist/pts/$abi/libConjure.so" "$TMP/release/libConjure-${abi}.so"
  done
  [[ -f "$ROOT/dist/pts/CLIENT_TRANSPORT_PLUGIN.txt" ]] && \
    cp -f "$ROOT/dist/pts/CLIENT_TRANSPORT_PLUGIN.txt" "$TMP/release/"
else
  echo "NOTE: skip PT build (install go, or use Actions build-and-publish.yml)."
fi

echo "Staging:"
ls -lh "$TMP/release"
(cd "$TMP/release" && sha256sum -- * > SHA256SUMS.txt)

NOTES="$(cat <<EOF
## Tor Android + pluggable transports (OnionVPN)

### Tor
\`libtor-*.so\` — built from source in this repo (\`scripts/build-libtor.sh\`).
arm64 may include \`-fsanitize=memtag\` (ENABLE_MTE=1).

### Pluggable transports
\`libLyrebird-*.so\` / \`libConjure-*.so\` — built with
\`-Wl,-z,max-page-size=16384\` (16 KB pages) and Go \`-checklinkname=0\`.

See \`CLIENT_TRANSPORT_PLUGIN.txt\`. Verify: \`sha256sum -c SHA256SUMS.txt\`
EOF
)"

ASSETS=( "$TMP/release"/* )

if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  echo "Updating existing release $TAG..."
  gh release upload "$TAG" "${ASSETS[@]}" --repo "$REPO" --clobber
  gh release edit "$TAG" --repo "$REPO" --notes "$NOTES"
else
  echo "Creating release $TAG..."
  gh release create "$TAG" "${ASSETS[@]}" \
    --repo "$REPO" \
    --title "$TAG" \
    --notes "$NOTES"
fi

echo "Done. OnionVPN fetch examples:"
echo "  https://github.com/${REPO}/releases/download/${TAG}/libLyrebird-arm64-v8a.so"
echo "  https://github.com/${REPO}/releases/latest/download/libtor-arm64-v8a.so"
