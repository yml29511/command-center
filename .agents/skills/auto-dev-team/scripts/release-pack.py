#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import re
import subprocess
from collections import Counter, defaultdict
from datetime import datetime
from pathlib import Path
from typing import Dict, Iterable, List, Sequence, Tuple


DOMAIN_RULES = {
    "ui": {
        "segments": {"ui", "page", "pages", "view", "views", "component", "components", "frontend", "web"},
        "suffixes": {".js", ".jsx", ".ts", ".tsx", ".vue", ".css", ".scss", ".less", ".html"},
        "label": "UI / GUI",
    },
    "api": {
        "segments": {"api", "apis", "controller", "controllers", "route", "routes", "handler", "handlers"},
        "suffixes": {".js", ".jsx", ".ts", ".tsx", ".py", ".go"},
        "label": "API / Controller",
    },
    "service": {
        "segments": {"service", "services", "usecase", "usecases", "workflow", "logic", "domain"},
        "suffixes": {".js", ".jsx", ".ts", ".tsx", ".py", ".go"},
        "label": "Service / Domain",
    },
    "data": {
        "segments": {
            "repo",
            "repos",
            "repository",
            "repositories",
            "dao",
            "daos",
            "mapper",
            "mappers",
            "model",
            "models",
            "entity",
            "entities",
            "migration",
            "migrations",
            "sql",
            "db",
            "database",
            "store",
            "stores",
        },
        "suffixes": {".sql", ".py", ".go", ".ts", ".tsx", ".js", ".jsx"},
        "label": "Data / DB",
    },
    "config": {
        "segments": {"config", "configs", "env", "settings"},
        "suffixes": {".json", ".yaml", ".yml", ".toml", ".ini", ".env"},
        "label": "Config",
    },
    "docs": {
        "segments": {"docs", "references", "assets"},
        "suffixes": {".md"},
        "label": "Docs",
    },
    "tests": {
        "segments": {"test", "tests", "__tests__", "spec"},
        "suffixes": {".spec.ts", ".test.ts", ".spec.js", ".test.js", ".spec.py", ".test.py"},
        "label": "Tests",
    },
}

ENTITY_STOPWORDS = {
    "src",
    "app",
    "lib",
    "core",
    "common",
    "shared",
    "service",
    "services",
    "controller",
    "controllers",
    "route",
    "routes",
    "handler",
    "handlers",
    "model",
    "models",
    "entity",
    "entities",
    "repository",
    "repositories",
    "repo",
    "dao",
    "db",
    "database",
    "migration",
    "migrations",
    "index",
    "utils",
    "util",
    "helper",
    "helpers",
    "page",
    "pages",
    "view",
    "views",
    "component",
    "components",
    "test",
    "tests",
    "spec",
    "mock",
    "mocks",
    "config",
    "configs",
    "readme",
    "references",
    "assets",
    "template",
    "templates",
    "skill",
    "skills",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate an interactive pre-release testing session draft from recent git commits."
    )
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--range", default="", help="Explicit git commit range, e.g. abc123..def456.")
    group.add_argument("--commit", default="", help="Single commit to inspect. Defaults to HEAD.")
    group.add_argument(
        "--commits",
        type=int,
        default=1,
        help="Use the latest N commits when --range/--commit is not provided. Default: 1.",
    )
    parser.add_argument("--task", default="", help="Short task description for the output header.")
    parser.add_argument("--env", default="预发", help="Environment label. Default: 预发.")
    parser.add_argument(
        "--output",
        default=".autodev/temp/release-test-pack.md",
        help="Markdown output path relative to repo root.",
    )
    parser.add_argument(
        "--json",
        default="",
        help="Optional JSON summary path relative to repo root.",
    )
    parser.add_argument(
        "--stdout",
        action="store_true",
        help="Also print the generated markdown to stdout.",
    )
    return parser.parse_args()


def run_cmd(command: Sequence[str], cwd: Path) -> str:
    proc = subprocess.run(
        command,
        cwd=str(cwd),
        check=False,
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or "command failed")
    return proc.stdout.strip()


def get_repo_root() -> Path:
    return Path(run_cmd(["git", "rev-parse", "--show-toplevel"], Path.cwd())).resolve()


def resolve_target(args: argparse.Namespace) -> Tuple[str, bool]:
    if args.range:
        return args.range, True
    if args.commit:
        return args.commit, False
    if args.commits <= 1:
        return "HEAD", False
    return f"HEAD~{args.commits}..HEAD", True


def get_commit_rows(repo_root: Path, target: str, is_range: bool) -> List[Tuple[str, str]]:
    if is_range:
        raw = run_cmd(["git", "log", "--reverse", "--format=%H%x09%s", target], repo_root)
    else:
        raw = run_cmd(["git", "show", "-s", "--format=%H%x09%s", target], repo_root)
    rows: List[Tuple[str, str]] = []
    for line in raw.splitlines():
        if not line.strip():
            continue
        commit_hash, _, subject = line.partition("\t")
        rows.append((commit_hash.strip(), subject.strip()))
    return rows


def get_changed_files(repo_root: Path, target: str, is_range: bool) -> List[Tuple[str, str]]:
    if is_range:
        raw = run_cmd(["git", "diff", "--name-status", target], repo_root)
    else:
        raw = run_cmd(["git", "show", "--name-status", "--format=", target], repo_root)
    rows: List[Tuple[str, str]] = []
    for line in raw.splitlines():
        if not line.strip():
            continue
        status, _, path = line.partition("\t")
        if path.strip():
            rows.append((status.strip(), path.strip()))
    return rows


def detect_domains(path_text: str) -> List[str]:
    path = Path(path_text)
    segments = {part.lower() for part in path.parts}
    suffix = path.suffix.lower()
    stem = path.name.lower()
    matched: List[str] = []
    for key, rule in DOMAIN_RULES.items():
        if segments & rule["segments"]:
            matched.append(key)
            continue
        if suffix in rule["suffixes"] or stem in rule["suffixes"]:
            matched.append(key)
    if not matched:
        matched.append("service")
    return matched


def extract_entities(paths: Iterable[str]) -> List[str]:
    counter: Counter[str] = Counter()
    for path_text in paths:
        path = Path(path_text)
        tokens = re.split(r"[^a-zA-Z0-9]+", "/".join(path.parts))
        for token in tokens:
            lowered = token.lower()
            if len(lowered) < 3:
                continue
            if lowered.isdigit() or lowered in ENTITY_STOPWORDS:
                continue
            counter[lowered] += 1
    return [token for token, _ in counter.most_common(3)]


def infer_need_queries(domains: Iterable[str]) -> bool:
    domain_set = set(domains)
    return bool(domain_set & {"data", "service", "api"})


def read_optional_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return ""


def detect_sql_dialect(repo_root: Path) -> Tuple[str, str]:
    candidates = [
        repo_root / ".autodev" / "path.md",
        repo_root / "docker-compose.yml",
        repo_root / "compose.yml",
        repo_root / "package.json",
        repo_root / "pyproject.toml",
        repo_root / "requirements.txt",
        repo_root / "go.mod",
        repo_root / ".env",
        repo_root / ".env.example",
        repo_root / "application.yml",
        repo_root / "application.yaml",
        repo_root / "application.properties",
    ]
    combined = "\n".join(read_optional_text(path).lower() for path in candidates if path.exists())
    if any(token in combined for token in ("postgresql", "postgres", "psycopg", "pgx", "asyncpg")):
        return "PostgreSQL", "从 path.md / 配置文件中识别到 postgres 相关信号"
    if any(token in combined for token in ("mysql", "mariadb", "pymysql")):
        return "MySQL", "从 path.md / 配置文件中识别到 mysql 相关信号"
    if any(token in combined for token in ("sqlite", ".db", "better-sqlite3")):
        return "SQLite", "从 path.md / 配置文件中识别到 sqlite 相关信号"
    return "待确认", "未从 path.md 或常见配置文件中识别出明确数据库方言"


def seven_day_filter(dialect: str) -> str:
    if dialect == "PostgreSQL":
        return "updated_at >= NOW() - INTERVAL '7 days'"
    if dialect == "MySQL":
        return "updated_at >= NOW() - INTERVAL 7 DAY"
    if dialect == "SQLite":
        return "updated_at >= DATETIME('now', '-7 days')"
    return "updated_at >= <请按实际数据库方言替换最近7天条件>"


def make_query_templates(entities: List[str], domains: Iterable[str], dialect: str) -> List[Dict[str, str]]:
    domain_set = set(domains)
    if not infer_need_queries(domain_set):
        return []

    entity = entities[0] if entities else "core"
    table_placeholder = f"<{entity}_table>"
    base_fields = "id, status, updated_at"
    queries = [
        {
            "id": "Q1",
            "purpose": f"找最近可用于验证 {entity} 相关变更的候选记录",
            "sql": f"SELECT {base_fields}\nFROM {table_placeholder}\nORDER BY updated_at DESC\nLIMIT 20;",
            "usage": "先确认预发里有没有最近可直接拿来手测的样本数据。",
        },
        {
            "id": "Q2",
            "purpose": f"看 {entity} 在不同状态下的分布，便于挑选边界 case",
            "sql": f"SELECT status, COUNT(*) AS cnt\nFROM {table_placeholder}\nGROUP BY status\nORDER BY cnt DESC;",
            "usage": "判断应该优先选哪种状态做 happy path、negative path 和 boundary path。",
        },
        {
            "id": "Q3",
            "purpose": f"回看最近一周 {entity} 的变化，筛出更贴近真实链路的记录",
            "sql": (
                f"SELECT {base_fields}\nFROM {table_placeholder}\n"
                f"WHERE {seven_day_filter(dialect)}\n"
                "ORDER BY updated_at DESC\nLIMIT 50;"
            ),
            "usage": "优先挑近期仍在流转的数据，减少测到过期脏数据的概率。",
        },
    ]
    if {"ui", "api"} & domain_set:
        queries.append(
            {
                "id": "Q4",
                "purpose": f"补一条可用于详情页或列表页直达验证的 {entity} 记录",
                "sql": f"SELECT {base_fields}\nFROM {table_placeholder}\nWHERE id = <待替换ID>;",
                "usage": "当 UI 需要直接粘贴单号或 ID 时，用它拿到一条可稳定复验的精确记录。",
            }
        )
    return queries


def make_test_data_rows(entities: List[str], domains: Iterable[str]) -> List[Dict[str, str]]:
    domain_labels = ", ".join(DOMAIN_RULES[key]["label"] for key in sorted(set(domains)) if key in DOMAIN_RULES)
    rows: List[Dict[str, str]] = []
    seeds = entities or ["核心对象"]
    for index, entity in enumerate(seeds[:3], start=1):
        rows.append(
            {
                "id": f"TD-{index}",
                "change": f"{entity} 相关最近提交",
                "purpose": f"覆盖 {entity} 相关的主验证链路",
                "method": "直接使用查询结果 / 手工造单 / 脚本造单",
                "fields": f"建议至少确认 `{entity}_id / status / updated_at`，并结合 {domain_labels or '核心业务字段'} 细化。",
                "expected": f"拿到一条可用于列表、详情或状态流转验证的 {entity} 样本数据。",
            }
        )
    return rows


def make_use_cases(entities: List[str], domains: Iterable[str]) -> List[Dict[str, str]]:
    seeds = entities or ["核心对象"]
    primary = seeds[0]
    use_cases = [
        {
            "id": "UC-1",
            "title": f"{primary} 主链路验证",
            "change": f"{primary} 相关最近提交",
            "preconditions": f"已拿到一条可直接搜索或粘贴的 {primary} 单号 / ID。",
            "why": "先确认最近提交对应的 happy path 在预发环境确实可走通。",
            "input": f"粘贴 `{primary}` 的单号 / ID。",
            "page": f"`{primary}` 列表页或首个可搜索入口。",
            "steps": [
                "在列表页或搜索框粘贴测试数据中的单号 / ID。",
                "点击“查询 / 搜索 / 筛选”。",
                "进入详情页或执行最近提交直接影响的按钮操作。",
            ],
            "expected": "页面状态、按钮显隐、字段展示或提交结果与最近提交描述一致。",
            "success": "说明本次改动影响到的主链路在预发环境可正常工作。",
            "failure": "查无数据、状态不符、按钮缺失、接口报错、页面提示异常。",
        },
        {
            "id": "UC-2",
            "title": f"{primary} 边界或负例验证",
            "change": f"{primary} 相关最近提交",
            "preconditions": f"已准备另一条状态不同或字段不完整的 {primary} 样本。",
            "why": "补一条最贴近本次改动的 boundary / negative case，避免只测 happy path。",
            "input": f"粘贴边界态 `{primary}` 的单号 / ID。",
            "page": f"`{primary}` 列表页、详情页或与本次改动最相关的操作弹窗。",
            "steps": [
                "打开与最近提交直接相关的页面或弹窗。",
                "输入边界态样本数据并触发查询或操作。",
                "观察页面提示、按钮状态和最终结果。",
            ],
            "expected": "错误提示、禁用状态或兜底逻辑符合预期，不出现误放行。",
            "success": "说明最近提交没有破坏异常链路或边界行为。",
            "failure": "错误提示缺失、误提交成功、页面状态错乱、数据回显不一致。",
        },
        {
            "id": "UC-3",
            "title": "回归观察",
            "change": "最近提交的关联旧链路",
            "preconditions": "准备一条旧路径仍应可用的历史样本数据。",
            "why": "验证最近提交没有误伤原有老链路或旧状态数据。",
            "input": "粘贴历史样本单号 / ID。",
            "page": "与主链路相同的入口页。",
            "steps": [
                "搜索历史样本数据。",
                "重复旧版本就应该可以走通的操作。",
                "对比页面展示与旧链路预期是否一致。",
            ],
            "expected": "旧路径仍能按原预期运行，且不会误触发本次新逻辑。",
            "success": "说明本次提交的影响范围相对收敛，没有明显回归。",
            "failure": "旧数据被新逻辑错误拦截、页面文案异常、状态映射被改坏。",
        },
    ]
    if "ui" not in set(domains):
        for case in use_cases:
            case["page"] = "调用该链路的业务页面或控制台入口。"
    return use_cases


def render_markdown(
    *,
    task: str,
    env_label: str,
    target: str,
    commits: List[Tuple[str, str]],
    changed_files: List[Tuple[str, str]],
    domains: List[str],
    entities: List[str],
    dialect: str,
    dialect_reason: str,
    queries: List[Dict[str, str]],
    test_data_rows: List[Dict[str, str]],
    use_cases: List[Dict[str, str]],
) -> str:
    created_at = datetime.now().strftime("%Y-%m-%d %H:%M")
    commit_summary = f"{commits[0][0][:7]} - {commits[0][1]}" if commits else "N/A"
    behavior_lines = [f"- `{commit_hash[:7]}` {subject}" for commit_hash, subject in commits] or ["- 无"]
    changed_file_lines = [f"- `{status}` `{path}`" for status, path in changed_files] or ["- 无"]
    domain_lines = [
        f"- {DOMAIN_RULES[key]['label']}" for key in sorted(set(domains)) if key in DOMAIN_RULES
    ] or ["- 未识别，建议人工补充"]
    entity_text = ", ".join(entities) if entities else "最近提交涉及的核心对象"
    need_queries = "需先查数" if queries else "可直接造单"
    task_text = task or "根据最近提交组织交互式预发测试"

    lines: List[str] = [
        "# 预发测试会话草稿",
        "",
        f"创建时间: {created_at}",
        f"任务: {task_text}",
        f"提交范围: `{target}`",
        f"环境: {env_label}",
        "",
        "> 仅供 agent 组织当前轮互动时使用，不是默认直接发给用户的最终静态交付物。",
        "",
        f"## 🛠️ 预发测试开始 {{{commit_summary}}}",
        "",
        f"- 本轮关注的最近提交: `{target}`",
        f"- 一句话场景摘要: 优先围绕 `{entity_text}` 相关变更做预发验收。",
        "- 为什么优先测这个: 这些文件和提交最接近最近行为变化，最容易在预发环境暴露真实回归。",
        "",
        "## 最近提交的行为变化摘要",
        "",
        *behavior_lines,
        "",
        "### 变更文件",
        "",
        *changed_file_lines,
        "",
        "### 推断影响域",
        "",
        *domain_lines,
        "",
        "## 是否需要先查数",
        "",
        f"- 结论: {need_queries}",
        "- 原因: "
        + (
            "最近提交涉及 API / Service / Data 路径，建议先从预发环境挑选真实样本数据。"
            if queries
            else "最近提交更偏 UI 或文档层，可先直接准备手测样本，再按实际页面补细节。"
        ),
        "",
        "## 🛠️ 先导数据库查询",
        "",
        "> 先把下面 SQL 发给用户去预发执行，等结果贴回后再继续更准确地造单。",
        "",
    ]

    if queries:
        lines.extend(
            [
                f"- 当前推断数据库方言: {dialect}",
                f"- 当前推断依据: {dialect_reason}",
                "",
                "```sql",
            ]
        )
        for query in queries:
            lines.extend(
                [
                    f"-- {query['id']}: {query['purpose']}",
                    query["sql"],
                    "",
                ]
            )
        lines.extend(["```", ""])
        for query in queries:
            lines.extend(
                [
                    f"- `{query['id']}` {query['purpose']}",
                    f"  结果回来后如何使用: {query['usage']}",
                ]
            )
        lines.extend(
            [
                f"- 备注: 当前按 {dialect} 语法生成；若与项目实际数据库不符，先按当前项目方言整体替换后再执行。",
                "",
            ]
        )
    else:
        lines.extend(
            [
                "- 本轮暂不强制查数；若后续发现页面路径或状态流仍不明确，再补一轮定向查询。",
                "",
            ]
        )

    lines.extend(
        [
            "## ⏸️ 等待预发查询结果",
            "",
            "- 请用户把整段查询结果贴回来。",
            "- 收到结果前，不继续生成最终测试数据单、use cases 和手测步骤。",
            "",
        ]
    )

    if not queries:
        lines.extend(
            [
                "## 🛠️ 开始生成测试数据单",
                "",
            ]
        )
        for row in test_data_rows:
            lines.extend(
                [
                    f"### {row['id']}",
                    "",
                    f"- 关联变更点: {row['change']}",
                    f"- 用途: {row['purpose']}",
                    f"- 造单方式: {row['method']}",
                    f"- 关键字段: {row['fields']}",
                    f"- 预期拿到的数据: {row['expected']}",
                    "",
                ]
            )

        lines.extend(
            [
                "## 🛠️ 可测 Use Cases",
                "",
            ]
        )
        for case in use_cases:
            lines.extend(
                [
                    f"### {case['id']} {case['title']}",
                    "",
                    f"- 关联变更: {case['change']}",
                    f"- 前置条件: {case['preconditions']}",
                    f"- 为什么要测: {case['why']}",
                    "",
                ]
            )

        lines.extend(
            [
                "## 🛠️ 预发手测步骤",
                "",
            ]
        )
        for case in use_cases:
            lines.extend(
                [
                    f"### {case['id']} {case['title']}",
                    "",
                    f"- 输入内容: {case['input']}",
                    f"- 打开页面: {case['page']}",
                    "- 操作步骤:",
                    *[f"  {index}. {step}" for index, step in enumerate(case["steps"], start=1)],
                    f"- 预期结果: {case['expected']}",
                    f"- 成功判定: {case['success']}",
                    f"- 失败表现: {case['failure']}",
                    "",
                ]
            )

    lines.extend(
        [
            "## ⚠️ 待确认项与剩余风险",
            "",
            "- 待确认项: 请结合实际表名、状态字段、页面路径和按钮名再补齐最后一跳。",
            "- 剩余风险: 当前脚本只能根据提交与文件路径生成骨架，仍需 AI 或人工结合业务语义细化。",
            "",
            "## ✅ 当前轮输出已准备",
            "",
            f"- 查询语句数量: {len(queries)}",
            f"- 测试数据单数量: {0 if queries else len(test_data_rows)}",
            f"- Use case 数量: {0 if queries else len(use_cases)}",
            "- 下一步建议: "
            + (
                "先执行查数 SQL，再把结果贴回来让 AI 收紧成具体单号、页面路径和点击动作。"
                if queries
                else "继续结合真实页面名、按钮名和业务对象，把骨架补成可直接执行的手测单，并等待用户按 use cases 去预发手测。"
            ),
            "",
        ]
    )
    return "\n".join(lines)


def build_summary(
    *,
    target: str,
    commits: List[Tuple[str, str]],
    changed_files: List[Tuple[str, str]],
    domains: List[str],
    entities: List[str],
    queries: List[Dict[str, str]],
) -> Dict[str, object]:
    grouped: Dict[str, List[str]] = defaultdict(list)
    for status, path in changed_files:
        grouped[status].append(path)
    return {
        "target": target,
        "commits": [{"hash": commit_hash, "subject": subject} for commit_hash, subject in commits],
        "changed_files": grouped,
        "domains": sorted(set(domains)),
        "entities": entities,
        "needs_queries": bool(queries),
        "query_count": len(queries),
    }


def write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def normalize_entities(entities: List[str], domains: Iterable[str]) -> List[str]:
    domain_set = set(domains)
    if domain_set and domain_set <= {"docs", "tests", "config"}:
        return []
    return entities


def main() -> int:
    args = parse_args()
    repo_root = get_repo_root()
    target, is_range = resolve_target(args)
    commits = get_commit_rows(repo_root, target, is_range)
    changed_files = get_changed_files(repo_root, target, is_range)
    file_paths = [path for _, path in changed_files]
    all_domains = [domain for path in file_paths for domain in detect_domains(path)]
    entities = normalize_entities(extract_entities(file_paths), all_domains)
    dialect, dialect_reason = detect_sql_dialect(repo_root)
    queries = make_query_templates(entities, all_domains, dialect)
    test_data_rows = make_test_data_rows(entities, all_domains)
    use_cases = make_use_cases(entities, all_domains)
    markdown = render_markdown(
        task=args.task,
        env_label=args.env,
        target=target,
        commits=commits,
        changed_files=changed_files,
        domains=all_domains,
        entities=entities,
        dialect=dialect,
        dialect_reason=dialect_reason,
        queries=queries,
        test_data_rows=test_data_rows,
        use_cases=use_cases,
    )

    output_path = (repo_root / args.output).resolve() if not Path(args.output).is_absolute() else Path(args.output)
    write_text(output_path, markdown + "\n")

    if args.json:
        summary = build_summary(
            target=target,
            commits=commits,
            changed_files=changed_files,
            domains=all_domains,
            entities=entities,
            queries=queries,
        )
        json_path = (repo_root / args.json).resolve() if not Path(args.json).is_absolute() else Path(args.json)
        write_text(json_path, json.dumps(summary, ensure_ascii=False, indent=2) + "\n")

    print(f"🛠️ release-pack 已生成: {output_path.relative_to(repo_root)}")
    if args.json:
        json_path = (repo_root / args.json).resolve() if not Path(args.json).is_absolute() else Path(args.json)
        print(f"JSON 已写入: {json_path.relative_to(repo_root)}")
    if args.stdout:
        print()
        print(markdown)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
