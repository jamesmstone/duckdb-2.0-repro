#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
for d in 0*/; do
  echo "═══ ${d%/}"
  bash "$d/run.sh"
  echo
done
