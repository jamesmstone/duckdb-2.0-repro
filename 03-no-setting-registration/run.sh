#!/usr/bin/env bash
# Shows that a V2 C extension cannot register a configuration setting, which
# V1 extensions can and do.
set -euo pipefail
cd "$(dirname "$0")"
source ../lib/header.sh

v2="$(v2_header)"; v1="$(v1_header)"
echo "duckdb/duckdb@$(header_ref)"
echo

echo "everything V2 can register:"
flatten_entries "$v2" | grep -E '_register\(' | sed -E 's/\(.*//' | sort -u | sed 's/^/  /'
echo
echo "V2's whole option surface:"
flatten_entries "$v2" | grep -E '^duckdb_v2_(option|[a-z]+_(get|set)_option)' \
  | sed -E 's/\(.*//' | sort -u | sed 's/^/  /'
echo
echo "what V1 offers for the same job:"
grep -oE '\(\*duckdb_[a-z_0-9]*config_option[a-z_0-9]*\)' "$v1" | tr -d '(*)' | sort -u | sed 's/^/  /'
echo
cat <<'TXT'
V2 registers functions, casts, copy functions, custom types and replacement
scans. It cannot register a setting. Its option entries all read or write
options that already exist --- get_option_by_name, set_option --- and there is
no create: an option handle can only be destroyed and inspected.

V1 has duckdb_create_config_option / duckdb_register_config_option, with
setters for name, type, default value, default scope and description. An
extension that exposes a setting, so users configure it with

    SET GLOBAL my_extension_option = '...';
    SELECT current_setting('my_extension_option');

has no equivalent under V2.
TXT
