# 写入模式共享前置

> 所有会写文件、改配置、生成测试或落存档的流程，都先走这里。默认保持 strict 行为；策略细节可由 `.autodev/autodev-config.json` 调整。

## 目录

- 适用模式
- 共享前置步骤（默认 strict）
- 测试台账规则
- Principles 激活矩阵
- 观测驱动验证启用规则
- GUI 自治验收闭环启用规则
- Patterns 按需读取
- 完成动作（写入模式通用）
- 禁止行为

## 适用模式

- Architect
- FastTrack
- Debug
- Refactor
- Optimize
- Hotfix
- Cleanup
- Tester
- Step（执行阶段）

`Survey` 和 `Explain` 默认只读，不进入本流程。

## 共享前置步骤（默认 strict）

1. 初始化 `.autodev/`。
   - 优先执行 `scripts/init-autodev.sh`
   - 若脚本不可用，再手工复制 `assets/templates/` 中的必需模板
   - 必需文档包括 `.autodev/autodev-config.json`
   - 必须确保 `.autodev/temp/` 存在，用于承接 AI 生成的临时产物
2. 执行工作区边界检查。
   - AI 生成的临时台账、调试输出、草稿、诊断材料，必须统一写入 `.autodev/temp/`
   - 若发现仓库其他路径存在 AI 生成的非交付临时文件，先迁移到 `.autodev/temp/`、清理，或加入 ignore 后再继续
3. 读取 `.autodev/context-snapshot.md`，恢复最近任务上下文。
4. 读取 `.autodev/autodev-config.json`，加载 skill 策略。
5. 若任务涉及 Git、部署、路径、环境、服务端配置、运行时路径、日志路径或控制台入口，先读取 `.autodev/path.md`。
6. 读取 `references/gotchas.md` 中与当前任务最相关的部分。
   - Git / 回退 / 分支 / 存档任务：重点看 checkpoint gotchas
   - “添加 / 删除 / 重写”类编辑任务：重点看保留性 gotchas
   - 跨模块 / monorepo / 契约变更：重点看影响分析 gotchas
7. 执行 `git log -5 --oneline`，判断最近改动与当前任务的关联或冲突。
8. 执行分支守卫。
   - 优先执行 `scripts/checkpoint.sh ensure-branch <task-slug>`
   - 若脚本不可用，按 `references/principles/checkpoint-mechanism.md` 手工执行
9. 🎯 建立里程碑（任务开始基线）。
   - 默认开启；优先执行 `scripts/checkpoint.sh milestone "<任务>#起点" "任务开始前基线" <task-slug>`
   - 若脚本不可用，按 `references/principles/checkpoint-mechanism.md` 手工执行
10. 💿 注册执行前快照闸门。
   - 不在此步建立快照，延迟到实际执行指令到达时强制触发
   - 优先执行 `scripts/checkpoint.sh snapshot-gate <task>`
11. 🧭 注册 Blast Radius 闸门。
   - 不在此步提前伪造报告，延迟到“第一行代码写入前”强制触发
   - 默认执行 `scripts/blast-radius.py ... --write`
   - 产物落到 `.autodev/current-blast-radius.md` 和 `.autodev/blast-radius/*.md`
12. 🧱 执行防屎山快速检查。
   - 先判断新增代码应融入现有模块还是新建
   - 先判断是否已有可复用实现
   - 先判断是否命中抽象机会；1-2 次不强抽象，3 次以上必须抽象
   - 若发现单文件职责继续膨胀，先拆分或升级模式，禁止直接堆叠

## 测试台账规则

- `.autodev/current-steps.md`：记录多步执行计划、每步覆盖场景、每步测试回执。
- `.autodev/current-test.md`：记录大测试的场景矩阵、执行记录、待业务确认问题、剩余风险，以及关键观测结论。
- `.autodev/current-debug.md`：记录复杂 Debug 的多轮假设、观测差异、修复与复诊结论。
- `.autodev/current-gui-test.js`：记录当前任务的 GUI 主测试入口；命中 GUI-capable task 时必须创建或更新，并确保其与当前改动直接对应。
- `.autodev/current-blast-radius.md`：记录最近一次 Blast Radius 结论；任何代码 / 测试 / 配置写入前都要刷新。
- 命中以下任一条件，视为**大测试**，缺失时必须初始化 `.autodev/current-test.md`：
  - 认证、支付、权限、审批、上传下载
  - 多步表单、多页面跳转、会话状态、核心用户链路
  - 外部系统联动、API / 数据契约变更、跨模块改动
  - 业务规则不清，需要先补齐场景或阈值
- 未命中大测试条件时，不强制创建 `current-test.md`，但仍必须输出 `🧾 测试回执`。

## Principles 激活矩阵

| 触发条件 | 必须读取 |
|----------|----------|
| 所有写入模式进入时 | `references/principles/critique.md` |
| 涉及 Git / 部署 / 路径 / 环境时 | `references/principles/path-system.md` |
| 任意代码或配置写入前 | `references/principles/checkpoint-mechanism.md` |
| 第一行代码写入前 | `references/principles/impact-analysis.md` |
| 开始实际执行代码改动时 | `references/principles/test-verification.md` |
| 任意会改变运行行为的代码或配置写入，在进入验证阶段前 | `references/principles/observation-driven-verification.md` |
| 命中 GUI-capable task（页面、窗口、表单、可点击界面）时 | `references/principles/gui-autonomous-loop.md` |
| 进入 Step 执行阶段时 | `references/principles/incremental-testable.md` |
| 新增或修改 `.feature` / step definitions 时 | `references/principles/bdd-testing.md` |
| 做抽象、提取共享模块、设计通用接口时 | `references/principles/abstraction-rules.md` |
| 准备写入 Pattern 时 | `references/patterns/README.md` |

## 观测驱动验证启用规则

- Architect：计划阶段必须为每个 Step 标注观测驱动验证档位与观测面。
- Step / FastTrack / Hotfix / Tester：只要当前改动影响运行行为，默认至少执行 `L1 轻量观测验证`。
- Debug：默认执行 `L2 标准观测验证`，复杂问题直接升到 `L3 重度观测验证`。
- Refactor：默认执行 `L3 重度观测验证`，建立 before / after 基线。
- 回归定位：默认执行 `L3`，优先建立可重复运行的 oracle。
- 复杂 Debug / 回归定位：若需要多轮诊断，创建或更新 `.autodev/current-debug.md`。

## GUI 自治验收闭环启用规则

- 任何 GUI-capable task 默认进入 `GUI 自治验收闭环`。
- Web GUI 默认选择 Playwright；其他 GUI 选择当前环境可用的 executor。
- 命中 GUI-capable task 时，必须先初始化或更新 `.autodev/current-gui-test.js`；若已有旧文件，必须先检查它与当前改动的文件/场景/风险是否直接对应。
- 若 `.autodev/current-gui-test.js` 不能直接映射当前步骤的改动点，必须重写；⛔ 禁止直接拿历史业务 E2E 脚本充当本步主验证。
- 现有仓库里的 GUI 脚本只能在 `.autodev/current-gui-test.js` 已通过后，作为补充回归使用，并在回执中明确标注“补充回归”。
- Web GUI 默认以 headed 方式运行；只有用户明确允许 headless，或当前环境无法展示浏览器时，才允许退化。
- GUI use case 未达到 `已通过 / 暂不可执行 / 用户明确禁用` 前，不得宣称任务完成。
- GUI 闭环执行失败时，默认进入“采证 → 修复 → 重跑同一 case”的自修复循环，最多 3 轮。
- 命中 GUI fallback 时，必须输出 `🧭 开发者手测教程`，不能只写“请手动验证”。

## Patterns 按需读取

- Architect / Refactor / Optimize：默认检查是否有可复用 Pattern。
- Debug：仅在历史问题、语言陷阱、平台特性明显相关时读取。
- FastTrack / Hotfix / Cleanup / Tester：默认不预读，只有出现明确复用需求时再读取。

## 完成动作（写入模式通用）

1. 先做脚本化 Blast Radius，并用结果刷新验证范围。
2. 再执行后台自动测试 + 对应档位的观测驱动验证；若命中 GUI-capable task，继续执行 `GUI 自治验收闭环` 并保留证据 / 测试回执。
3. 再建立存档，输出固定回执：

```text
💾【存档】{任务}#{序号} → {hash}
```

4. 若达到阶段性完成点，询问是否合并到集成分支、是否推送。

## 禁止行为

- 跳过共享前置直接开始写代码。
- 未读 `path.md` 就做 Git / 部署 / 服务器路径相关操作。
- 跳过 Blast Radius 闸门直接写代码。
- 跳过验证直接建立存档。
- 把观测驱动验证误写成“只在测试失败后才启用”。
- 命中大测试却不创建 / 更新 `.autodev/current-test.md`。
- 把 `Cleanup`、`Tester` 当成“非写入模式”处理。
- 命中 GUI-capable task 却不准备 `.autodev/current-gui-test.js`。
- 用历史 GUI 脚本替代当前改动直连的 GUI 主验证。
