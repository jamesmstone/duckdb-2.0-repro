#!/usr/bin/env bash
# Fetches DuckDB's C extension headers at the pinned commit, into tmp/, once.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$ROOT/tmp"

# The commit the staged alpha these repros pin was built from.
HEADER_REF="${DUCKDB_REF:-31adc8b766}"

header_ref() { printf '%s' "$HEADER_REF"; }

fetch_header() {
  local name=$1 dest="$TMP/$1"
  [ -f "$dest" ] && { printf '%s' "$dest"; return; }
  mkdir -p "$TMP"
  curl --fail --silent --show-error --location -o "$dest" \
    "https://raw.githubusercontent.com/duckdb/duckdb/$HEADER_REF/src/include/$name"
  printf '%s' "$dest"
}

v1_header() { fetch_header duckdb_extension.h; }
v2_header() { fetch_header duckdb_extension_v2.h; }

# One function-table entry per line, so a signature that wraps in the header
# can still be matched whole.
flatten_entries() {
  perl -0777 -ne '
    while (/DUCKDB_V2_ERROR\s*\(\*(duckdb_v2_\w+)\)\s*\(([^;]*?)\);/gs) {
      my ($name, $args) = ($1, $2);
      $args =~ s/\s+/ /g;
      print "$name($args)\n";
    }
  ' "$1"
}

v2_core_header() { fetch_header duckdb_v2.h; }
