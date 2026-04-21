#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INIT_SCRIPT="$SKILL_ROOT/scripts/init-autodev.sh"
CHECKPOINT_SCRIPT="$SKILL_ROOT/scripts/checkpoint.sh"

fail() {
  printf 'checkpoint-selftest: %s\n' "$1" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  if [[ "$haystack" != *"$needle"* ]]; then
    fail "expected output to contain: $needle"
  fi
}

TMPDIR_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_ROOT"' EXIT

REPO_DIR="$TMPDIR_ROOT/repo"
mkdir -p "$REPO_DIR"
cd "$REPO_DIR"

git init -q
git config user.name "Checkpoint Selftest"
git config user.email "checkpoint-selftest@example.com"
printf 'seed\n' > README.md
git add README.md
git commit -q -m "init"

"$INIT_SCRIPT" "$REPO_DIR" >/dev/null

milestone_output="$("$CHECKPOINT_SCRIPT" milestone "脚本验证#起点" "checkpoint selftest" gui-checkpoint)"
assert_contains "$milestone_output" "🎯 里程碑"
assert_contains "$milestone_output" "指纹: 脚本验证#起点"
assert_contains "$milestone_output" "标签: milestone/gui-checkpoint-"

gate_output="$("$CHECKPOINT_SCRIPT" snapshot-gate "脚本验证")"
assert_contains "$gate_output" "💿"

printf 'delta\n' >> README.md
archive_output="$("$CHECKPOINT_SCRIPT" archive "脚本验证#01" chore "checkpoint selftest archive")"
assert_contains "$archive_output" "💾【存档】脚本验证#01"

list_output="$("$CHECKPOINT_SCRIPT" list)"
assert_contains "$list_output" "📍 存档列表"
assert_contains "$list_output" "脚本验证#起点"
assert_contains "$list_output" "脚本验证#01"

printf 'checkpoint selftest passed\n'
