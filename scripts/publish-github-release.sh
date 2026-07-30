#!/usr/bin/env bash
# Seed or refresh GitHub Release assets for OnionVPN (LTechnologies0 fork).
# Downloads current CI artifacts from the Gedsh GitLab job (same NDK build),
# then uploads them to this repo's releases so OnionVPN never imports Gedsh URLs directly.
#
# Usage:
#   ./scripts/publish-github-release.sh [tag]
# Default tag: tor-0.4.9.11-dev
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TAG="${1:-tor-0.4.9.11-dev}"
TMP="${TMPDIR:-/tmp}/ltech-tor-android-publish"
mkdir -p "$TMP"

REPO="${GITHUB_REPOSITORY:-LTechnologies0/Tor-Android-build-script}"

TOR_ARMV7_URL='https://gitlab.com/Gedsh/tor-android-build-script/-/jobs/artifacts/master/raw/tor-android-binary/src/main/libs/armeabi-v7a/libtor.so?job=android%20r23b%2022%20default%20armeabi-v7a'
TOR_ARM64_URL='https://gitlab.com/Gedsh/tor-android-build-script/-/jobs/artifacts/master/raw/tor-android-binary/src/main/libs/arm64/libtor.so?job=android%20r23b%2022%20default%20arm64-v8a'
TOR_X86_64_URL='https://gitlab.com/Gedsh/tor-android-build-script/-/jobs/artifacts/master/raw/tor-android-binary/src/main/libs/x86_64/libtor.so?job=android%20r23b%2022%20default%20x86_64'

echo "Fetching Tor binaries (source build: Gedsh GitLab CI → republish as $REPO@$TAG)..."
curl -fsSL -L -o "$TMP/libtor-armeabi-v7a.so" "$TOR_ARMV7_URL"
curl -fsSL -L -o "$TMP/libtor-arm64-v8a.so" "$TOR_ARM64_URL"
curl -fsSL -L -o "$TMP/libtor-x86_64.so" "$TOR_X86_64_URL"

for f in libtor-armeabi-v7a.so libtor-arm64-v8a.so libtor-x86_64.so; do
  bytes=$(wc -c <"$TMP/$f")
  if [[ "$bytes" -lt 1000000 ]]; then
    echo "ERROR: $f too small ($bytes bytes)" >&2
    exit 1
  fi
  echo "  $f ($bytes bytes)"
done

if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  echo "Updating existing release $TAG..."
  gh release upload "$TAG" \
    "$TMP/libtor-armeabi-v7a.so" \
    "$TMP/libtor-arm64-v8a.so" \
    "$TMP/libtor-x86_64.so" \
    --repo "$REPO" --clobber
else
  echo "Creating release $TAG..."
  gh release create "$TAG" \
    "$TMP/libtor-armeabi-v7a.so" \
    "$TMP/libtor-arm64-v8a.so" \
    "$TMP/libtor-x86_64.so" \
    --repo "$REPO" \
    --title "$TAG" \
    --notes "Tor Android \`libtor.so\` for OnionVPN (LTechnologies0 fork of Gedsh/Tor-Android-build-script).

Built via upstream NDK r23b GitLab CI; republished here so OnionVPN imports only this fork's release URLs.

ABIs: armeabi-v7a, arm64-v8a, x86_64."
fi

echo "Done. OnionVPN should fetch:"
echo "  https://github.com/${REPO}/releases/download/${TAG}/libtor-arm64-v8a.so"
echo "  https://github.com/${REPO}/releases/latest/download/libtor-arm64-v8a.so"
