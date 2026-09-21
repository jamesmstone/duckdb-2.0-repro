#!/usr/bin/env bash
# Shows that a V2 C extension cannot reach the instance it was loaded into.
#
# Proved against the headers rather than by building an extension: the claim is
# about which entries exist, and the header is the whole surface.
set -euo pipefail
cd "$(dirname "$0")"
source ../lib/header.sh

ext="$(v2_header)"; core="$(v2_core_header)"
entries="$(flatten_entries "$ext")"
echo "duckdb/duckdb@$(header_ref) — $(printf '%s\n' "$entries" | wc -l) entries in duckdb_ext_api_v2"
echo

show() {
  echo "$1"
  local hits; hits="$(printf '%s\n' "$entries" | grep -E "$2" | sed -E 's/\(.*//' | sort -u)"
  if [ -z "$hits" ]; then echo "  (none)"; else printf '%s\n' "$hits" | sed 's/^/  /'; fi
  echo
}

show "hands back a connection:" 'duckdb_v2_connection_handle \*out'
show "hands back an instance:"  'duckdb_v2_instance_handle \*out'
show "takes an extension handle:" 'duckdb_v2_extension_handle [a-z]'
show "the whole context surface:" '^duckdb_v2_context'

echo "and their signatures:"
printf '%s\n' "$entries" | grep -E '^duckdb_v2_(connection_create|instance_create|environment_create)\(' | sed 's/^/  /'
echo
echo "what the entrypoint is handed:"
awk '/duckdb_v2_extension_input \{/,/\};/' "$core" | grep -E '^[[:space:]]+(duckdb_v2|[a-z])' | sed 's/^/  /'
echo
cat <<'TXT'
A connection comes only from connection_create, which needs an instance; an
instance comes only from instance_create, which makes a NEW one from an
environment. Nothing maps the extension or context handle the entrypoint
receives onto either, and the context is documented "Valid only until the
extension entrypoint returns; do not retain or destroy it".

The seven *_with_extension entries register functions, and that is the whole
of what an extension handle can do.

So an extension that must hold a connection for the life of the process ---
to serve a request, or to write outside the transaction of the query that
invoked it --- cannot obtain one. Under V1 the entrypoint is handed the
database directly, via duckdb_extension_access.get_database.
TXT
