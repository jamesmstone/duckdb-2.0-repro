#!/usr/bin/env bash
# Fetches the two DuckDB CLIs these repros compare, into bin/, once.
#
# Both come from DuckDB's own distribution: the stable one from
# install.duckdb.org, the pre-release from the staging bucket the official
# installer reads when DUCKDB_VERSION=alpha.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/bin"

# The alpha these findings were recorded against. Set DUCKDB_ALPHA=latest to
# chase the current one instead — it moves, and so may the results.
PINNED_ALPHA="${DUCKDB_ALPHA:-31adc8b766/v2.0.0-alpha42839}"
STABLE_VERSION="${DUCKDB_STABLE:-1.5.5}"

case "$(uname -s)-$(uname -m)" in
  Linux-x86_64)  DIST=linux-amd64 ;;
  Linux-aarch64) DIST=linux-arm64 ;;
  Darwin-*)      DIST=osx-universal ;;
  *) echo "unsupported platform: $(uname -s)-$(uname -m)" >&2; exit 1 ;;
esac

resolve_alpha() {
  if [ "$PINNED_ALPHA" = latest ]; then
    curl --fail --silent --show-error https://duckdb-staging.duckdb.org/latest_alpha_version.txt
  else
    printf '%s' "$PINNED_ALPHA"
  fi
}

fetch_stable() {
  [ -x "$BIN/duckdb-stable" ] && return 0
  mkdir -p "$BIN"
  echo "fetching duckdb v$STABLE_VERSION" >&2
  curl --fail --silent --show-error --location \
    "https://install.duckdb.org/v$STABLE_VERSION/duckdb_cli-$DIST.gz" \
    | gunzip > "$BIN/duckdb-stable"
  chmod +x "$BIN/duckdb-stable"
}

fetch_alpha() {
  [ -x "$BIN/duckdb-alpha" ] && return 0
  mkdir -p "$BIN"
  local staged; staged="$(resolve_alpha)"
  echo "fetching duckdb $staged" >&2
  curl --fail --silent --show-error --location \
    "https://duckdb-staging.duckdb.org/$staged/duckdb/duckdb/github_release/duckdb-cli-$DIST.tar.gz" \
    | tar -xzO duckdb > "$BIN/duckdb-alpha"
  chmod +x "$BIN/duckdb-alpha"
}

# DUCKDB_STABLE_BIN / DUCKDB_ALPHA_BIN short-circuit the download. The nix
# devShell sets them, because NixOS cannot run a generic dynamically linked
# binary without patching it first.
duckdb_stable() {
  if [ -n "${DUCKDB_STABLE_BIN:-}" ]; then printf "%s" "$DUCKDB_STABLE_BIN"; return; fi
  fetch_stable; printf "%s" "$BIN/duckdb-stable"
}

duckdb_alpha() {
  if [ -n "${DUCKDB_ALPHA_BIN:-}" ]; then printf "%s" "$DUCKDB_ALPHA_BIN"; return; fi
  fetch_alpha; printf "%s" "$BIN/duckdb-alpha"
}
