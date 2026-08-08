#!/usr/bin/env bash
# Fail if an Android ELF needs non-Bionic third-party shared libs.
# Allowlist: libc, libm, libdl, liblog (Android system).
#
# Usage:
#   ./scripts/verify-android-standalone.sh path/to/libtor.so [more.so ...]
#   ./scripts/verify-android-standalone.sh --dir dist/
set -euo pipefail

ALLOW='^(libc|libm|libdl|liblog)\.so$'
READELF="$(command -v llvm-readelf || command -v readelf || true)"
if [[ -z "$READELF" ]]; then
  echo "ERROR: readelf/llvm-readelf required" >&2
  exit 1
fi

collect=()
if [[ "${1:-}" == "--dir" ]]; then
  shift
  root="${1:?dir}"
  while IFS= read -r -d '' f; do
    collect+=("$f")
  done < <(find "$root" -type f -name '*.so' -print0 | sort -z)
else
  collect=("$@")
fi

if [[ ${#collect[@]} -eq 0 ]]; then
  echo "ERROR: no .so files to check" >&2
  exit 1
fi

fail=0
for so in "${collect[@]}"; do
  [[ -f "$so" ]] || { echo "ERROR: missing $so" >&2; fail=1; continue; }
  mapfile -t needed < <("$READELF" -d "$so" 2>/dev/null | grep NEEDED | sed -n 's/.*\[\(.*\)\].*/\1/p')
  bad=()
  for lib in "${needed[@]}"; do
    [[ -z "$lib" ]] && continue
    if ! [[ "$lib" =~ $ALLOW ]]; then
      bad+=("$lib")
    fi
  done
  if [[ ${#bad[@]} -gt 0 ]]; then
    echo "FAIL $so — non-standalone NEEDED: ${bad[*]}" >&2
    echo "  full NEEDED: ${needed[*]}" >&2
    fail=1
  else
    echo "OK standalone $(basename "$so") (NEEDED: ${needed[*]})"
  fi
done

exit "$fail"
