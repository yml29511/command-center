#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STEPS_FILE="$REPO_ROOT/.autodev/temp/blast-radius-step-selftest.md"

mkdir -p "$REPO_ROOT/.autodev/temp"

cat >"$STEPS_FILE" <<'EOF'
# 当前任务

## 关键决策 (防遗忘，每步执行前必读)

- **Log 标识**: [DEV-blast-radius-step-selftest]

## 计划 (每步必须增量可测)

- [ ] 🌀 Step 1: 自检通过路径 [可测产出: selftest] [Blast Radius: scripts/init-autodev.sh::copy_if_missing → ≤🔴]
- [ ] 🌀 Step 2: 自检拦截路径 [可测产出: selftest] [Blast Radius: scripts/init-autodev.sh::copy_if_missing → ≤🟢]
EOF

"$REPO_ROOT/scripts/blast-radius-step.sh" \
  --steps-file "$STEPS_FILE" \
  --step 1 \
  --task "blast-radius-step-selftest-pass" \
  --no-current \
  --quiet >/dev/null

if "$REPO_ROOT/scripts/blast-radius-step.sh" \
  --steps-file "$STEPS_FILE" \
  --step 2 \
  --task "blast-radius-step-selftest-fail" \
  --no-current \
  --quiet >/dev/null 2>&1; then
  echo "blast-radius-step-selftest.sh: expected threshold fail-close did not happen" >&2
  exit 1
fi

echo "✅ blast-radius-step 自检通过"
