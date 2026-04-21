#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RELEASE_PACK_SCRIPT="$SKILL_ROOT/scripts/release-pack.py"

fail() {
  printf 'release-pack-selftest: %s\n' "$1" >&2
  exit 1
}

assert_file_contains() {
  local file_path="$1"
  local needle="$2"
  if ! grep -q -- "$needle" "$file_path"; then
    fail "expected $file_path to contain: $needle"
  fi
}

TMPDIR_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_ROOT"' EXIT

REPO_DIR="$TMPDIR_ROOT/repo"
mkdir -p "$REPO_DIR"
cd "$REPO_DIR"

git init -q
git config user.name "Release Pack Selftest"
git config user.email "release-pack-selftest@example.com"

mkdir -p src/services src/repositories
cat > README.md <<'EOF'
# release-pack selftest
EOF
git add README.md
git commit -q -m "chore: seed repository"

cat > src/services/order-service.ts <<'EOF'
export function updateOrderStatus(id: string, status: string) {
  return { id, status };
}
EOF
git add src/services/order-service.ts
git commit -q -m "feat: add order status service"

cat > src/repositories/order-repository.ts <<'EOF'
export function findRecentOrders() {
  return [];
}
EOF
git add src/repositories/order-repository.ts
git commit -q -m "feat: add order repository"

OUTPUT_PATH=".autodev/temp/release-test-pack.md"
JSON_PATH=".autodev/temp/release-pack-summary.json"

python3 "$RELEASE_PACK_SCRIPT" \
  --commits 2 \
  --task "release-pack selftest" \
  --output "$OUTPUT_PATH" \
  --json "$JSON_PATH" >/dev/null

[[ -f "$OUTPUT_PATH" ]] || fail "expected markdown output file to exist"
[[ -f "$JSON_PATH" ]] || fail "expected json summary file to exist"

assert_file_contains "$OUTPUT_PATH" "## 🛠️ 预发测试开始"
assert_file_contains "$OUTPUT_PATH" "## 🛠️ 先导数据库查询"
assert_file_contains "$OUTPUT_PATH" "## ⏸️ 等待预发查询结果"
assert_file_contains "$OUTPUT_PATH" "## ✅ 当前轮输出已准备"
assert_file_contains "$OUTPUT_PATH" '```sql'
assert_file_contains "$OUTPUT_PATH" "SELECT id, status, updated_at"
assert_file_contains "$OUTPUT_PATH" "-- Q1:"
assert_file_contains "$OUTPUT_PATH" "order"

assert_file_contains "$JSON_PATH" '"query_count"'
assert_file_contains "$JSON_PATH" '"needs_queries": true'
assert_file_contains "$JSON_PATH" '"entities"'

printf 'release-pack selftest passed\n'
