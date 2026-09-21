#!/usr/bin/env bash
# Measures time-to-first-row against both DuckDB versions, at two scan sizes.
#
# The query streams: DuckDB can emit the first row long before the scan that
# produces the rest has finished. v1.5.5 does. v2.0.0-alpha does not.
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck source=../lib/duckdb.sh
source ../lib/duckdb.sh

REPS="${REPS:-5}"
SIZES="${SIZES:-20000000 200000000}"

sql() {
  cat <<SQL
COPY (
  SELECT 'head' AS c
  UNION ALL
  SELECT '<li>' || i || '</li>' FROM range($1) r(i) WHERE (r.i * 2654435761) % 97 = 3
) TO '/dev/stdout' (FORMAT csv);
SQL
}

# Time to the first row, and to the last, in milliseconds. The whole result is
# drained so the total is a real completion time rather than a broken pipe.
measure() {
  local db=$1 n=$2 start first end
  start=$(date +%s%N)
  "$db" -c "$(sql "$n")" 2>/dev/null | {
    IFS= read -r _first_line
    date +%s%N > .first
    cat > /dev/null
  }
  end=$(date +%s%N)
  first=$(cat .first); rm -f .first
  echo "$(( (first - start) / 1000000 )) $(( (end - start) / 1000000 ))"
}

median() { tr ' ' '\n' | sort -n | awk '{v[NR]=$1} END {print v[int((NR+1)/2)]}'; }

printf '%-18s %-12s %14s %12s\n' version rows first-row-ms total-ms
printf '%-18s %-12s %14s %12s\n' ------- ---- ------------ --------
for n in $SIZES; do
  for db_name in stable alpha; do
    db=$("duckdb_$db_name")
    version=$("$db" -noheader -list -c 'select version();')
    firsts=(); totals=()
    for _ in $(seq "$REPS"); do
      read -r f t < <(measure "$db" "$n")
      firsts+=("$f"); totals+=("$t")
    done
    printf '%-18s %-12s %14s %12s\n' "$version" "$n" \
      "$(printf '%s ' "${firsts[@]}" | median)" \
      "$(printf '%s ' "${totals[@]}" | median)"
  done
done

echo
echo "medians of $REPS runs. the query, at the smaller size:"
sql "$(echo "$SIZES" | cut -d' ' -f1)"
