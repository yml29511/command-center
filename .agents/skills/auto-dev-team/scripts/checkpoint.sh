#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: checkpoint.sh <command> [args]

Commands:
  ensure-branch <task-slug>
  milestone <fingerprint> [description] [task-slug]
  snapshot-gate [task]
  archive <fingerprint> [type] [description]
  list
  rollback <hash>
EOF
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

if ! REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  echo "checkpoint.sh: current directory is not inside a git repository" >&2
  exit 1
fi

cd "$REPO_ROOT"
CONFIG_FILE="$REPO_ROOT/.autodev/autodev-config.json"

json_get() {
  local path="$1"
  local fallback="$2"

  if [[ ! -f "$CONFIG_FILE" ]]; then
    printf '%s\n' "$fallback"
    return 0
  fi

  python3 - "$CONFIG_FILE" "$path" "$fallback" <<'PY'
import json
import sys

config_path, dotted_path, fallback = sys.argv[1:]

try:
    with open(config_path, "r", encoding="utf-8") as fh:
        data = json.load(fh)
except Exception:
    print(fallback)
    raise SystemExit(0)

value = data
for part in dotted_path.split("."):
    if not isinstance(value, dict) or part not in value:
        print(fallback)
        raise SystemExit(0)
    value = value[part]

if isinstance(value, bool):
    print("true" if value else "false")
elif isinstance(value, list):
    for item in value:
        print(item)
else:
    print(value)
PY
}

timestamp() {
  date "+%m%d%H%M"
}

actor_slug() {
  local raw
  raw="$(git config user.name || true)"
  raw="${raw%% *}"
  raw="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '-')"
  raw="${raw#-}"
  raw="${raw%-}"
  printf '%s\n' "${raw:-agent}"
}

slugify() {
  local raw="${1:-task}"
  raw="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '-')"
  raw="${raw#-}"
  raw="${raw%-}"
  printf '%s\n' "${raw:-task}"
}

current_branch() {
  git branch --show-current
}

integration_mode() {
  json_get "integration_mode" "merge_allowed"
}

protected_branches() {
  json_get "protected_branches" "main"
}

matches_branch_pattern() {
  local branch="$1"
  local pattern
  while IFS= read -r pattern; do
    [[ -z "$pattern" ]] && continue
    if [[ "$branch" == $pattern ]]; then
      return 0
    fi
  done < <(protected_branches)
  return 1
}

repo_is_dirty() {
  [[ -n "$(git status --porcelain)" ]]
}

last_subject() {
  git log -1 --pretty=%s 2>/dev/null || true
}

review_staging() {
  local mode="$1"
  local branch_mode
  branch_mode="$(integration_mode)"
  local -a staged=()
  local staged_file
  while IFS= read -r staged_file; do
    staged+=("$staged_file")
  done < <(git diff --cached --name-only)
  [[ ${#staged[@]} -eq 0 ]] && return 0

  local file
  for file in "${staged[@]}"; do
    case "$file" in
      .env|.env.*|*.pem|*.key|*.p12|credentials.*|secrets.*)
        git reset HEAD -- "$file" >/dev/null 2>&1 || true
        echo "⛔ 已从暂存区移除敏感文件: $file" >&2
        ;;
      .autodev/*|.cursor/*)
        if [[ "$mode" == "archive" && "$branch_mode" == "pr_only" ]]; then
          git reset HEAD -- "$file" >/dev/null 2>&1 || true
          echo "⛔ pr_only 模式下已移出暂存区: $file" >&2
        elif [[ "$mode" == "archive" ]]; then
          echo "⚠️ 暂存区发现非代码文件: $file" >&2
        fi
        ;;
    esac
  done
}

ensure_branch() {
  local task_slug
  task_slug="$(slugify "${1:-task}")"

  local branch
  branch="$(current_branch)"
  if ! matches_branch_pattern "$branch"; then
    echo "🌿 已在工作分支: $branch"
    return 0
  fi

  local branch_mode new_branch
  branch_mode="$(integration_mode)"
  if [[ "$branch_mode" == "pr_only" ]]; then
    new_branch="autodev/$(actor_slug)/${task_slug}-$(timestamp)"
  else
    new_branch="autodev/${task_slug}-$(timestamp)"
  fi

  git switch -c "$new_branch" >/dev/null
  local base_hash
  base_hash="$(git rev-parse --short HEAD)"

  cat <<EOF
━━━━━━━━━━━━━━━━━━━━
🌿 已创建工作分支
分支: $new_branch
基于: $branch ($base_hash)
━━━━━━━━━━━━━━━━━━━━
EOF
}

create_milestone() {
  local fingerprint="${1:?fingerprint required}"
  local description="${2:-任务开始前基线}"
  local task_slug
  task_slug="$(slugify "${3:-$fingerprint}")"

  git add -A
  review_staging "milestone"
  git commit --allow-empty -m "「${fingerprint}」chore: ${description}" >/dev/null

  local tag_base tag_name idx hash
  tag_base="milestone/${task_slug}-$(timestamp)"
  if [[ "$(integration_mode)" == "pr_only" ]]; then
    tag_base="milestone/$(actor_slug)/${task_slug}-$(timestamp)"
  fi
  tag_name="$tag_base"
  idx=2
  while git rev-parse -q --verify "refs/tags/$tag_name" >/dev/null 2>&1; do
    tag_name="${tag_base}-${idx}"
    idx=$((idx + 1))
  done
  git tag "$tag_name"
  hash="$(git rev-parse --short HEAD)"

  cat <<EOF
━━━━━━━━━━━━━━━━━━━━
🎯 里程碑
━━━━━━━━━━━━━━━━━━━━
指纹: ${fingerprint}
哈希: ${hash}
标签: ${tag_name}
━━━━━━━━━━━━━━━━━━━━
💡 随时可说「回退到 ${fingerprint}」
━━━━━━━━━━━━━━━━━━━━
EOF
}

snapshot_gate() {
  local task="${1:-现场保护}"
  local subject
  subject="$(last_subject)"

  if repo_is_dirty; then
    git add -A
    review_staging "snapshot"
    git commit -m "「${task}#保护」chore: 自动存档" >/dev/null
    echo "💿 已保护 → $(git rev-parse --short HEAD)（执行前闸门）"
    return 0
  fi

  if [[ "$subject" == *"「${task}"* || "$subject" == *"#保护"* || "$subject" == *"#起点"* ]]; then
    echo "💿 闸门通过（基线 $(git rev-parse --short HEAD) 即保护点）"
    return 0
  fi

  git commit --allow-empty -m "「${task}#保护」chore: 自动存档" >/dev/null
  echo "💿 已保护 → $(git rev-parse --short HEAD)（执行前闸门）"
}

archive_commit() {
  local fingerprint="${1:?fingerprint required}"
  local kind="${2:-chore}"
  local description="${3:-自动存档}"

  if ! repo_is_dirty; then
    echo "ℹ️ 无改动，跳过存档"
    return 0
  fi

  git add -A
  review_staging "archive"
  git commit -m "「${fingerprint}」${kind}: ${description}" >/dev/null
  echo "💾【存档】${fingerprint} → $(git rev-parse --short HEAD)"
}

list_archives() {
  local -a milestones=() snapshots=() archives=()
  local hash subject
  while IFS=$'\t' read -r hash subject; do
    [[ "$subject" != *"「"* ]] && continue
    if [[ -n "$(git tag --points-at "$hash" | grep '^milestone/' || true)" ]]; then
      milestones+=("$hash|$subject")
      continue
    fi
    if [[ "$subject" == *"#保护"* ]]; then
      [[ ${#snapshots[@]} -lt 1 ]] && snapshots+=("$hash|$subject")
      continue
    fi
    [[ ${#archives[@]} -lt 3 ]] && archives+=("$hash|$subject")
  done < <(git log --pretty='%h%x09%s' -50)

  echo "━━━━━━━━━━━━━━━━━━━━"
  echo "📍 存档列表"
  echo "━━━━━━━━━━━━━━━━━━━━"
  local idx=1 item
  if (( ${#milestones[@]} )); then
    for item in "${milestones[@]}"; do
      IFS='|' read -r hash subject <<<"$item"
      echo "[$idx] 🎯 ${hash} ${subject}"
      idx=$((idx + 1))
    done
  fi
  if (( ${#snapshots[@]} )); then
    for item in "${snapshots[@]}"; do
      IFS='|' read -r hash subject <<<"$item"
      echo "[$idx] 💿 ${hash} ${subject}"
      idx=$((idx + 1))
    done
  fi
  if (( ${#archives[@]} )); then
    for item in "${archives[@]}"; do
      IFS='|' read -r hash subject <<<"$item"
      echo "[$idx] 💾 ${hash} ${subject}"
      idx=$((idx + 1))
    done
  fi
  echo "━━━━━━━━━━━━━━━━━━━━"
  echo "回退到哪个？（输入序号或指纹）"
  echo "━━━━━━━━━━━━━━━━━━━━"
}

rollback_to() {
  local target="${1:?hash required}"
  local branch
  branch="$(current_branch)"
  if matches_branch_pattern "$branch"; then
    cat <<EOF
━━━━━━━━━━━━━━━━━━━━
⚠️ 当前在受保护分支 $branch 上，无法直接回退
请选择切换到工作分支后再回退
━━━━━━━━━━━━━━━━━━━━
EOF
    exit 1
  fi

  if repo_is_dirty; then
    snapshot_gate "现场保存"
  fi

  git reset --hard "$target" >/dev/null
  cat <<EOF
━━━━━━━━━━━━━━━━━━━━
✅ 已回退
当前位置: $(git log -1 --pretty=%s) $(git rev-parse --short HEAD)
分支: $branch
━━━━━━━━━━━━━━━━━━━━
EOF
}

command="${1:-}"
shift || true

case "$command" in
  ensure-branch)
    ensure_branch "$@"
    ;;
  milestone)
    create_milestone "$@"
    ;;
  snapshot-gate)
    snapshot_gate "$@"
    ;;
  archive)
    archive_commit "$@"
    ;;
  list)
    list_archives
    ;;
  rollback)
    rollback_to "$@"
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    echo "Unknown command: $command" >&2
    usage
    exit 1
    ;;
esac
