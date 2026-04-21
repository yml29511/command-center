# auto-dev-team

> 一个面向软件开发任务的 Agent Skill：自动选模式、结构化执行、即时验证、可回退。

[![Agent Skills](https://img.shields.io/badge/Agent%20Skills-Compatible-blue)](https://agentskills.io)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## 本次更新

- Brainstorm 模式：先讨论需求、边界与验收标准，再进入实现规划
- current-flow + flowctl：把 `current-*` 产物纳入 active flow 管理，减少上下文漂移
- Brainstorm Review + Quality Review：执行后先检查是否做对题，再检查代码质量
- 预发测试 plan + manual/auto 双执行器
- 内部安装方式保留 Cursor / Qoder 的 GitLab 安装入口

## 目录

- 本次更新
- 简介
- 安装
- 最近更新
- Agent Quick Start
- 当前入口结构
- 目录结构
- 主要模式
- V2 测试协议
- 使用方式
- 配置与脚本
- PM 资源
- 许可证

## 简介

`auto-dev-team` 基于 [Agent Skills 规范](https://agentskills.io/specification) 构建，并以更偏 harness 的方式组织软件交付流程。目标是把“开发流程知识”拆成可组合、可按需加载的文档和脚本，而不是把所有规则都堆进 `SKILL.md`。

**仓库地址**：`https://code.alibaba-inc.com/cainiao-ai-skills/AutoDevTeam`

核心思路：

- 主入口保持轻量
- 模式判断和写前置分离
- Principles 按模式、阶段、产物触发
- 机械步骤优先交给脚本，减少重复推理
- Skill 策略由 `.autodev/autodev-config.json` 配置
- 所有改动都要求验证和可回退
- 第一行代码写入前默认执行脚本化 Blast Radius
- 代码变更后默认执行后台自动测试
- GUI-capable task 默认进入 GUI 自治验收闭环
- Web GUI 支持 `Script-first Playwright` 和 `Suite-first Playwright`
- 大测试使用 `.autodev/current-test.md` 记录场景、执行和风险

## 安装

### Cursor 安装方式

**方式一：全局安装**

```bash
cd ~/.cursor/skills/
git clone git@gitlab.alibaba-inc.com:cainiao-ai-skills/AutoDevTeam.git auto-dev-team
```

**方式二：项目级安装**

```bash
cd your-project/.cursor/skills/
git clone git@gitlab.alibaba-inc.com:cainiao-ai-skills/AutoDevTeam.git auto-dev-team
```

### Qoder 安装方式

```bash
cd ~/.qoder/skills/
git clone git@gitlab.alibaba-inc.com:cainiao-ai-skills/AutoDevTeam.git auto-dev-team
```

## 最近更新

- 版本说明见 [CHANGELOG.md](CHANGELOG.md)
- 当前重点能力：
  - Brainstorm 模式：先讨论需求、边界与验收标准，再进入实现规划
  - current-flow + flowctl：把 `current-*` 产物纳入 active flow 管理，减少上下文漂移
  - Brainstorm Review + Quality Review：执行后先检查是否做对题，再检查代码质量
  - 预发测试 plan + manual/auto 双执行器

## Agent Quick Start

- 先读 `SKILL.md`
- 写入模式前，先读 `references/mode-index.md`
- 再读 `references/write-preflight.md`
- 改脚本后，运行对应 selftest
- 公司内部使用内网仓库安装

## 当前入口结构

```text
SKILL.md
references/mode-index.md
references/write-preflight.md
references/modes/*/README.md
references/principles/*.md
```

## 目录结构

```text
auto-dev-team/
├── SKILL.md
├── .cursor/
│   └── agents/
│       └── critique.md
├── agents/
│   └── openai.yaml
├── assets/
│   └── templates/
│       ├── autodev-config.json
│       ├── context-snapshot.md
│       ├── current-test.md
│       ├── current-steps.md
│       ├── current-blast-radius.md
│       ├── forbidden-zones.md
│       ├── module-registry.md
│       ├── gui-case-matrix.md
│       ├── gui-evidence-bundle.md
│       ├── path.md
│       ├── playwright-script-loop.js
│       ├── postmortem.md
│       ├── project-map.md
│       ├── release-test-pack.md
│       └── verification-checklist.md
├── scripts/
│   ├── blast-radius.py
│   ├── blast-radius-step.sh
│   ├── blast-radius-selftest.sh
│   ├── blast-radius-step-selftest.sh
│   ├── checkpoint.sh
│   ├── checkpoint-selftest.sh
│   ├── release-pack.py
│   ├── release-pack-selftest.sh
│   └── init-autodev.sh
└── references/
    ├── gotchas.md
    ├── mode-index.md
    ├── shared/
    │   └── flow-snippets.md
    ├── write-preflight.md
    ├── modes/
    │   ├── architect/README.md
    │   ├── cleanup/README.md
    │   ├── debug/README.md
    │   ├── explain/README.md
    │   ├── fasttrack/README.md
    │   ├── hotfix/README.md
    │   ├── optimize/README.md
    │   ├── refactor/README.md
    │   ├── step/README.md
    │   ├── survey/README.md
    │   └── tester/README.md
    ├── patterns/
    ├── pm-guide/
    └── principles/
```

## 主要模式

| 模式 | 触发场景 | 用途 |
|------|----------|------|
| Architect | 新功能、实现需求 | 方案设计与拆步 |
| Debug | bug、报错、异常 | 先诊断后修复 |
| Hotfix | 线上故障、紧急止血 | 最小改动恢复服务 |
| FastTrack | 小改动、文案、样式 | 快速处理单点变更 |
| Refactor | 重构、拆分、提取 | 控制风险地下刀 |
| Optimize | 性能问题 | 先诊断再优化 |
| Cleanup | 删除冗余、死代码 | 安全清理 |
| Tester | 新增测试、补覆盖、验证 use case、预发验收、发版手测 | 测试资产与交互式验证流程 |
| Survey | 了解项目结构 | 项目测绘 |
| Explain | 解释代码 | 帮助理解 |
| Step | Architect / Refactor / Optimize 的执行阶段 | 逐步落地 |

## V2 测试协议

- `行为场景层`：PM 可读的 use case、异常链路、边界 case。
- `Blast Radius 闸门`：改代码前先扫描目标文件/符号、直接调用方、邻近测试、reverse import chain 和风险等级。
- `Step Blast Radius wrapper`：Step 模式优先由 `scripts/blast-radius-step.sh` 从 `current-steps.md` 自动解析 target 和阈值，减少手填参数。
- `后台自动测试层`：代码变更后默认执行，优先覆盖改动点、边界和直接影响面。
- `GUI 自治验收层`：命中页面流程、窗口、表单、会话、权限、可交互界面等风险时，AI 默认执行 GUI executor；Web 默认 Playwright。
- `Web GUI executor`：既接受 `npx playwright test`，也接受 `node xxx.ui.test.js` 的脚本式 Playwright 闭环。
- `人工验收层`：视觉、体感、外部系统等难以稳定自动化的部分。
- `交互式预发测试层`：根据最近提交先提炼行为变化；若无法准确造单，则先生成查数 SQL，等待用户回贴结果后，再整理测试数据单、可测 use cases 与手测步骤。
- `小测试`：输出 `🧾 测试回执`。
- `大测试`：创建 `.autodev/current-test.md`，持续记录场景矩阵、执行状态和剩余风险。

## 使用方式

在支持 Agent Skills 的工具中安装后，直接用自然语言描述任务即可。

示例：

- “帮我做一个用户登录功能”
- “这个接口突然报 500”
- “把按钮颜色改成蓝色”
- “这段代码太乱了，帮我重构”
- “根据最近提交带我走一遍预发测试”

## 配置与脚本

- 项目环境与路径：`.autodev/path.md`
- Skill 策略与阈值：`.autodev/autodev-config.json`
- 初始化 `.autodev/`：`scripts/init-autodev.sh`
- 写入前 Blast Radius：`scripts/blast-radius.py`
- Step 模式 Blast Radius 包装：`scripts/blast-radius-step.sh`
- Blast Radius 自检：`scripts/blast-radius-selftest.sh`
- Step 包装自检：`scripts/blast-radius-step-selftest.sh`
- 版本保护原语：`scripts/checkpoint.sh`
- checkpoint 自检：`scripts/checkpoint-selftest.sh`
- 交互式预发测试会话草稿生成：`scripts/release-pack.py`
- 预发验收包自检：`scripts/release-pack-selftest.sh`
- 高频坑位沉淀：`references/gotchas.md`

### 交互式预发测试脚本示例

给后续 agent 的标准调用示例：

```bash
python3 scripts/release-pack.py --commits 3 --task "最近三次提交的预发验收"
python3 scripts/release-pack.py --range abc123..def456 --task "审批流改造预发验收"
bash scripts/release-pack-selftest.sh
```

## PM 资源

- `references/pm-guide/task-templates.md`
- `references/pm-guide/common-commands.md`
- `references/pm-guide/conversation-tips.md`

## 许可证

MIT License
