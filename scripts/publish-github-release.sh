#!/usr/bin/env bash
# Seed or refresh GitHub Release assets for OnionVPN (LTechnologies0 fork).
#
# - libtor-*.so: republished from Gedsh GitLab CI (same NDK build)
# - libLyrebird-*.so / libConjure-*.so: built locally via
#   scripts/build-pluggable-transports.sh when ANDROID_NDK_HOME is set,
#   otherwise skipped (use Actions workflow build-and-publish.yml).
#
# Usage:
#   ./scripts/publish-github-release.sh [tag]
# Default tag: tor-0.4.9.11-dev
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TAG="${1:-tor-0.4.9.11-dev}"
TMP="${TMPDIR:-/tmp}/ltech-tor-android-publish"
mkdir -p "$TMP/release"

REPO="${GITHUB_REPOSITORY:-LTechnologies0/Tor-Android-build-script}"

TOR_ARMV7_URL='https://gitlab.com/Gedsh/tor-android-build-script/-/jobs/artifacts/master/raw/tor-android-binary/src/main/libs/armeabi-v7a/libtor.so?job=android%20r23b%2022%20default%20armeabi-v7a'
TOR_ARM64_URL='https://gitlab.com/Gedsh/tor-android-build-script/-/jobs/artifacts/master/raw/tor-android-binary/src/main/libs/arm64/libtor.so?job=android%20r23b%2022%20default%20arm64-v8a'
TOR_X86_64_URL='https://gitlab.com/Gedsh/tor-android-build-script/-/jobs/artifacts/master/raw/tor-android-binary/src/main/libs/x86_64/libtor.so?job=android%20r23b%2022%20default%20x86_64'

echo "Fetching Tor binaries (Gedsh GitLab CI → $REPO@$TAG)..."
curl -fsSL -L -o "$TMP/release/libtor-armeabi-v7a.so" "$TOR_ARMV7_URL"
curl -fsSL -L -o "$TMP/release/libtor-arm64-v8a.so" "$TOR_ARM64_URL"
curl -fsSL -L -o "$TMP/release/libtor-x86_64.so" "$TOR_X86_64_URL"

if [[ -n "${ANDROID_NDK_HOME:-}" ]] && command -v go >/dev/null 2>&1; then
  echo "Building pluggable transports (16 KB page size)..."
  chmod +x "$ROOT/scripts/build-pluggable-transports.sh"
  ABIS="${ABIS:-arm64-v8a x86_64 armeabi-v7a}" "$ROOT/scripts/build-pluggable-transports.sh"
  for abi in arm64-v8a x86_64 armeabi-v7a; do
    [[ -f "$ROOT/dist/pts/$abi/libLyrebird.so" ]] && \
      cp -f "$ROOT/dist/pts/$abi/libLyrebird.so" "$TMP/release/libLyrebird-${abi}.so"
    [[ -f "$ROOT/dist/pts/$abi/libConjure.so" ]] && \
      cp -f "$ROOT/dist/pts/$abi/libConjure.so" "$TMP/release/libConjure-${abi}.so"
  done
  [[ -f "$ROOT/dist/pts/CLIENT_TRANSPORT_PLUGIN.txt" ]] && \
    cp -f "$ROOT/dist/pts/CLIENT_TRANSPORT_PLUGIN.txt" "$TMP/release/"
else
  echo "NOTE: skip PT build (set ANDROID_NDK_HOME + install go, or use Actions)."
fi

echo "Staging:"
ls -lh "$TMP/release"
(cd "$TMP/release" && sha256sum -- * > SHA256SUMS.txt)

NOTES="$(cat <<EOF
## Tor Android + pluggable transports (OnionVPN)

### Tor
\`libtor-*.so\` — republished from Gedsh NDK r23b CI.

### Pluggable transports
\`libLyrebird-*.so\` / \`libConjure-*.so\` — built with
\`-Wl,-z,max-page-size=16384\` (16 KB pages) and Go \`-checklinkname=0\` for Android.

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
