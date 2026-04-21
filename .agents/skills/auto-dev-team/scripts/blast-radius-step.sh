#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: blast-radius-step.sh [options]

Parse Blast Radius targets from .autodev/current-steps.md and run scripts/blast-radius.py.

Options:
  --step N            Step number to run. Defaults to the first unchecked plan step.
  --steps-file PATH   Step plan file. Defaults to .autodev/current-steps.md
  --task SLUG         Task slug passed through to blast-radius.py
  --mode MODE         Mode passed through to blast-radius.py. Default: step
  --depth N           Override reverse import depth
  --max-refs N        Override max refs per section
  --report PATH       Optional markdown report path override
  --json PATH         Optional JSON report path override
  --no-current        Do not refresh .autodev/current-blast-radius.md
  --quiet             Print concise wrapper output
  -h, --help          Show this help

Step plan syntax:
  [Blast Radius: path/to/file::symbol → ≤🟡]
  [Blast Radius: foo.ts::run, bar.ts::parse → ≤🔴]
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "${PWD}" rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
  echo "blast-radius-step.sh: current directory is not inside a git repository" >&2
  exit 1
fi

cd "$REPO_ROOT"

STEP_ID=""
STEPS_FILE=".autodev/current-steps.md"
TASK_SLUG=""
MODE="step"
DEPTH=""
MAX_REFS=""
REPORT_PATH=""
JSON_PATH=""
NO_CURRENT=0
QUIET=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --step)
      STEP_ID="${2:-}"
      shift 2
      ;;
    --steps-file)
      STEPS_FILE="${2:-}"
      shift 2
      ;;
    --task)
      TASK_SLUG="${2:-}"
      shift 2
      ;;
    --mode)
      MODE="${2:-}"
      shift 2
      ;;
    --depth)
      DEPTH="${2:-}"
      shift 2
      ;;
    --max-refs)
      MAX_REFS="${2:-}"
      shift 2
      ;;
    --report)
      REPORT_PATH="${2:-}"
      shift 2
      ;;
    --json)
      JSON_PATH="${2:-}"
      shift 2
      ;;
    --no-current)
      NO_CURRENT=1
      shift
      ;;
    --quiet)
      QUIET=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "blast-radius-step.sh: unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ ! -f "$STEPS_FILE" ]]; then
  echo "blast-radius-step.sh: steps file not found: $STEPS_FILE" >&2
  exit 3
fi

PARSE_JSON="$(python3 - "$STEPS_FILE" "$STEP_ID" <<'PY'
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

steps_path = Path(sys.argv[1])
requested_step = sys.argv[2].strip()
text = steps_path.read_text(encoding="utf-8")

plan_steps = []
for line in text.splitlines():
    match = re.match(r"^\s*-\s*\[(?P<mark>[ xX])\]\s*.*?\bStep\s+(?P<step>\d+)\s*:\s*(?P<title>.+?)\s*$", line)
    if not match:
        continue
    title = re.split(r"\s+\[(?=[^\]]+\])", match.group("title"), maxsplit=1)[0].strip()
    blast_match = re.search(r"\[Blast Radius:\s*(?P<spec>[^\]]+)\]", line)
    plan_steps.append(
        {
            "step": match.group("step"),
            "checked": match.group("mark").strip().lower() == "x",
            "title": title,
            "line": line,
            "blast_spec": blast_match.group("spec").strip() if blast_match else "",
        }
    )

if not plan_steps:
    raise SystemExit("steps file does not contain any Step plan line")

selected = None
if requested_step:
    for item in plan_steps:
        if item["step"] == requested_step:
            selected = item
            break
    if selected is None:
        raise SystemExit(f"requested Step {requested_step} not found in plan")
else:
    for item in plan_steps:
        if not item["checked"]:
            selected = item
            break
    if selected is None:
        selected = plan_steps[0]

blast_spec = selected["blast_spec"]
if not blast_spec:
    raise SystemExit(f"Step {selected['step']} is missing [Blast Radius: ...] annotation")

parts = re.split(r"\s*(?:→|->)\s*", blast_spec, maxsplit=1)
if len(parts) != 2:
    raise SystemExit(
        f"Step {selected['step']} Blast Radius annotation must include a threshold arrow: {blast_spec}"
    )
targets_part, threshold_part = parts
targets = [item.strip() for item in re.split(r"\s*[,;|，；]\s*", targets_part) if item.strip()]
if not targets:
    raise SystemExit(f"Step {selected['step']} Blast Radius annotation has no targets")

threshold_text = threshold_part.strip()
threshold_map = {
    "🟢": 1,
    "green": 1,
    "low": 1,
    "低": 1,
    "🟡": 2,
    "yellow": 2,
    "medium": 2,
    "中": 2,
    "🔴": 3,
    "red": 3,
    "high": 3,
    "高": 3,
}
normalized = threshold_text.replace("<=", "≤").replace(" ", "")
threshold_rank = None
for needle, rank in threshold_map.items():
    if needle in normalized:
        threshold_rank = rank
        break
if threshold_rank is None:
    raise SystemExit(
        f"Step {selected['step']} Blast Radius threshold is not recognized: {threshold_text}"
    )

log_marker = ""
for line in text.splitlines():
    log_match = re.search(r"\*\*Log 标识\*\*:\s*\[([^\]]+)\]", line)
    if log_match:
        log_marker = log_match.group(1).strip()
        break

payload = {
    "step": selected["step"],
    "title": selected["title"],
    "line": selected["line"],
    "targets": targets,
    "threshold_text": threshold_text,
    "threshold_rank": threshold_rank,
    "log_marker": log_marker,
}
print(json.dumps(payload, ensure_ascii=False))
PY
)"

STEP_META_TITLE="$(python3 - "$PARSE_JSON" <<'PY'
import json, sys
print(json.loads(sys.argv[1])["title"])
PY
)"
STEP_META_ID="$(python3 - "$PARSE_JSON" <<'PY'
import json, sys
print(json.loads(sys.argv[1])["step"])
PY
)"
STEP_META_THRESHOLD_TEXT="$(python3 - "$PARSE_JSON" <<'PY'
import json, sys
print(json.loads(sys.argv[1])["threshold_text"])
PY
)"
STEP_META_THRESHOLD_RANK="$(python3 - "$PARSE_JSON" <<'PY'
import json, sys
print(json.loads(sys.argv[1])["threshold_rank"])
PY
)"
STEP_META_LOG_MARKER="$(python3 - "$PARSE_JSON" <<'PY'
import json, sys
print(json.loads(sys.argv[1])["log_marker"])
PY
)"

STEP_TARGETS=()
while IFS= read -r line; do
  STEP_TARGETS+=("$line")
done < <(python3 - "$PARSE_JSON" <<'PY'
import json, sys
for item in json.loads(sys.argv[1])["targets"]:
    print(item)
PY
)

slugify() {
  python3 - "$1" <<'PY'
import re, sys
value = re.sub(r"[^A-Za-z0-9]+", "-", sys.argv[1]).strip("-").lower()
print(value or "step")
PY
}

if [[ -z "$TASK_SLUG" ]]; then
  if [[ -n "$STEP_META_LOG_MARKER" ]]; then
    TASK_SLUG="$(slugify "$STEP_META_LOG_MARKER")"
  else
    TASK_SLUG="step${STEP_META_ID}-$(slugify "$STEP_META_TITLE")"
  fi
fi

SUMMARY_PATH=".autodev/temp/blast-radius-step-summary.json"
mkdir -p ".autodev/temp"

cmd=("$SCRIPT_DIR/blast-radius.py" "--mode" "$MODE" "--step" "$STEP_META_ID" "--task" "$TASK_SLUG" "--write" "--summary-json" "$SUMMARY_PATH" "--threshold-label" "$STEP_META_THRESHOLD_TEXT")
if [[ -n "$DEPTH" ]]; then
  cmd+=("--depth" "$DEPTH")
fi
if [[ -n "$MAX_REFS" ]]; then
  cmd+=("--max-refs" "$MAX_REFS")
fi
if [[ -n "$REPORT_PATH" ]]; then
  cmd+=("--report" "$REPORT_PATH")
fi
if [[ -n "$JSON_PATH" ]]; then
  cmd+=("--json" "$JSON_PATH")
fi
if [[ "$NO_CURRENT" -eq 1 ]]; then
  cmd+=("--no-current")
fi
if [[ "$QUIET" -eq 1 ]]; then
  cmd+=("--quiet")
fi

for target in "${STEP_TARGETS[@]}"; do
  if [[ "$target" == *"::"* ]]; then
    cmd+=("--target" "$target")
  elif [[ "$target" == */* || "$target" == *.* ]]; then
    cmd+=("--file" "$target")
  else
    cmd+=("--symbol" "$target")
  fi
done

"${cmd[@]}"

python3 - "$SUMMARY_PATH" "$STEP_META_THRESHOLD_RANK" "$STEP_META_THRESHOLD_TEXT" "$STEP_META_ID" <<'PY'
from __future__ import annotations

import json
import sys

summary_path, threshold_rank, threshold_text, step_id = sys.argv[1:]
with open(summary_path, "r", encoding="utf-8") as fh:
    summary = json.load(fh)

actual_rank = int(summary["risk_rank"])
threshold_rank = int(threshold_rank)
if actual_rank > threshold_rank:
    print(
        f"⛔ Step {step_id} Blast Radius 超阈值：实际风险 {summary['risk_level']}，计划阈值 {threshold_text}。"
    )
    print(f"报告: {summary.get('report_path') or '.autodev/current-blast-radius.md'}")
    print("请先缩小改动范围或回到计划层重写 Step。")
    raise SystemExit(4)

print(
    f"✅ Step {step_id} Blast Radius 通过：实际风险 {summary['risk_level']}，阈值 {threshold_text}。"
)
print(f"报告: {summary.get('report_path') or '.autodev/current-blast-radius.md'}")
PY
