#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

mkdir -p "$REPO_ROOT/.autodev/temp"

REPORT_PATH=".autodev/temp/blast-radius-selftest.md"
JSON_PATH=".autodev/temp/blast-radius-selftest.json"

"$REPO_ROOT/scripts/blast-radius.py" \
  --file "scripts/init-autodev.sh" \
  --symbol "copy_if_missing" \
  --task "blast-radius-selftest" \
  --mode "fasttrack" \
  --depth 2 \
  --no-current \
  --report "$REPORT_PATH" \
  --json "$JSON_PATH" \
  --quiet >/dev/null

grep -q "Blast Radius Report" "$REPO_ROOT/$REPORT_PATH"
grep -q "风险等级" "$REPO_ROOT/$REPORT_PATH"
grep -q '"risk_level"' "$REPO_ROOT/$JSON_PATH"

echo "✅ blast-radius 自检通过"
