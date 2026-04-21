#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: init-autodev.sh [project_dir]

Initialize .autodev in the target git repository:
  - create required markdown templates
  - create autodev-config.json
  - ensure .git/info/exclude contains .autodev/
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE_DIR="$SKILL_ROOT/assets/templates"
TARGET_DIR="${1:-$(pwd)}"

if ! REPO_ROOT="$(git -C "$TARGET_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
  echo "init-autodev.sh: target is not inside a git repository: $TARGET_DIR" >&2
  exit 1
fi

AUTODEV_DIR="$REPO_ROOT/.autodev"
EXCLUDE_FILE="$REPO_ROOT/.git/info/exclude"

mkdir -p "$AUTODEV_DIR"
mkdir -p "$AUTODEV_DIR/temp"
mkdir -p "$AUTODEV_DIR/blast-radius"

copy_if_missing() {
  local source_file="$1"
  local dest_file="$2"

  if [[ -e "$dest_file" ]]; then
    return 0
  fi

  cp "$source_file" "$dest_file"
  echo "📄 已创建: ${dest_file#$REPO_ROOT/}（使用模板初始化）"
}

copy_if_missing "$TEMPLATE_DIR/context-snapshot.md" "$AUTODEV_DIR/context-snapshot.md"
copy_if_missing "$TEMPLATE_DIR/project-map.md" "$AUTODEV_DIR/project-map.md"
copy_if_missing "$TEMPLATE_DIR/module-registry.md" "$AUTODEV_DIR/module-registry.md"
copy_if_missing "$TEMPLATE_DIR/postmortem.md" "$AUTODEV_DIR/postmortem.md"
copy_if_missing "$TEMPLATE_DIR/path.md" "$AUTODEV_DIR/path.md"
copy_if_missing "$TEMPLATE_DIR/forbidden-zones.md" "$AUTODEV_DIR/forbidden-zones.md"
copy_if_missing "$TEMPLATE_DIR/autodev-config.json" "$AUTODEV_DIR/autodev-config.json"
copy_if_missing "$TEMPLATE_DIR/current-blast-radius.md" "$AUTODEV_DIR/current-blast-radius.md"

touch "$EXCLUDE_FILE"
if ! grep -qxF ".autodev/" "$EXCLUDE_FILE"; then
  printf '\n.autodev/\n' >>"$EXCLUDE_FILE"
  echo "🛡️ 已将 .autodev/ 加入 .git/info/exclude（本地忽略，不影响项目 .gitignore）"
fi
