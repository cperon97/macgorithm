# Shared helpers (sourced)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/config.sh"
WORK="${WORK:-$ROOT/work}"; DL="$WORK/downloads"; mkdir -p "$DL"
# downloads (unless cached) and verifies the SHA-256; prints ONLY the path on stdout (messages go to stderr)
fetch() {
  local url="$1" sha="$2" out="$DL/$(basename "$1")"
  if ! { [ -f "$out" ] && echo "$sha  $out" | shasum -a 256 -c --status; }; then
    echo ">> download $(basename "$out")" >&2
    # Integrity is guaranteed by the pinned SHA-256: if the site's TLS certificate is invalid
    # (as with flowgorithm.org) retry without TLS verification; a tampered file is still rejected.
    curl -fsSL --retry 3 -o "$out" "$url" 2>/dev/null || curl -fsSLk --retry 3 -o "$out" "$url" \
      || { echo "!! download failed: $url" >&2; exit 1; }
    echo "$sha  $out" | shasum -a 256 -c --status || { echo "!! SHA-256 mismatch: $out" >&2; exit 1; }
  fi
  echo "$out"
}
