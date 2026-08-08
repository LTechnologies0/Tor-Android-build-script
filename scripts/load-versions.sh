#!/usr/bin/env bash
# Source from build scripts:  . "$(dirname "$0")/load-versions.sh"
# Loads versions.properties into env (only if var unset).
set -euo pipefail

_VERS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
_VERS_FILE="${_VERS_ROOT}/versions.properties"

prop() {
  local key="$1"
  grep -E "^${key}=" "$_VERS_FILE" | head -1 | cut -d= -f2- | tr -d '[:space:]'
}

: "${OPENSSL_REF:=$(prop openssl.ref)}"
: "${LIBEVENT_REF:=$(prop libevent.ref)}"
: "${ZSTD_REF:=$(prop zstd.ref)}"
: "${XZ_REF:=$(prop xz.ref)}"
: "${XZ_REPO:=$(prop xz.repo)}"
: "${ZLIB_REF:=$(prop zlib.ref)}"
: "${ZLIB_REPO:=$(prop zlib.repo)}"
: "${TOR_REF:=$(prop tor.ref)}"
: "${TOR_REPO:=$(prop tor.repo)}"
: "${LYREBIRD_REF:=$(prop lyrebird.ref)}"
: "${LYREBIRD_REPO:=$(prop lyrebird.repo)}"
: "${CONJURE_REF:=$(prop conjure.ref)}"
: "${CONJURE_REPO:=$(prop conjure.repo)}"
: "${DNSCRYPT_REF:=$(prop dnscrypt.ref)}"
: "${DNSCRYPT_REPO:=$(prop dnscrypt.repo)}"

export OPENSSL_REF LIBEVENT_REF ZSTD_REF XZ_REF XZ_REPO ZLIB_REF ZLIB_REPO
export TOR_REF TOR_REPO LYREBIRD_REF LYREBIRD_REPO CONJURE_REF CONJURE_REPO
export DNSCRYPT_REF DNSCRYPT_REPO
