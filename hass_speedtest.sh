#!/usr/bin/env bash
set -euo pipefail

# Paths (adjust if needed)
SPEEDTEST_BIN="/usr/bin/speedtest"
CACHE="/opt/home-assistant/.last_speedtest.json"

# Create a temp file and ensure it’s removed on any exit
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

# Run the official CLI with a 120 s timeout
if OUTPUT="$(timeout 120s "$SPEEDTEST_BIN" --accept-license --server-id 61186 --format=json 2>/dev/null)"; then
  # Check it really looks like JSON
  if [[ "${OUTPUT:0:1}" == "{" ]]; then
    echo "$OUTPUT" > "$TMP"
    # Force‑move without prompting, using the full path to mv
    /bin/mv -f "$TMP" "$CACHE"
    echo "$OUTPUT"
    exit 0
  else
    echo "ERROR: speedtest returned non-JSON" >&2
  fi
else
  echo "ERROR: speedtest command failed or timed out" >&2
fi

# Fallback to last cache
if [[ -f "$CACHE" ]]; then
  cat "$CACHE"
  exit 0
else
  echo "ERROR: no cache file at $CACHE" >&2
  exit 1
fi
