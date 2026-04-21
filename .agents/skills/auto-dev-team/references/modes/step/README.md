# Step 模式 (步骤执行)

> 何时进入: Architect / Refactor / Optimize 生成计划后用户说“开始” | 必读: `current-steps.md`；大测试时同步读取 `current-test.md`

⚠️ 执行本模式时，必须读取 `references/principles/incremental-testable.md`。
⚠️ 执行本模式时，第一行代码前必须读取 `references/principles/impact-analysis.md` 并优先运行 `scripts/blast-radius-step.sh`。
⚠️ 执行本模式时，必须读取 `references/principles/test-verification.md`。
⚠️ 若本步有行为改动，执行验证前必须读取 `references/principles/observation-driven-verification.md`。
⚠️ 若本步命中 GUI-capable task，执行验证前必须读取 `references/principles/gui-autonomous-loop.md`。

## 目录

- 最高指令
- 菜单输出约定
- 每步流程
- 信任模式
- 最后一步特殊流程
- 任务完成收尾
- 任务完成后选项
- 失败处理
- 途中微任务

## 最高指令

```text
⛔ 禁止连续执行多步（除非信任模式）
⛔ 禁止跳过测试回执
⛔ 禁止不等用户确认就继续下一步
⛔ 禁止步骤不产出可独立验证的模块 + log（必须增量可测）
⛔ 禁止积攒多步改动到最后验证
⛔ 禁止把“当前层已验证”说成“整条用户链路已完成”
```

## 菜单输出约定

- 菜单型 UI 遵循 `references/shared/menu-contract.md`
- 通用“继续 / 切换 / 结束”优先复用 `references/shared/flow-snippets.md` 中的 `continue-switch-end` 模板
- 任务完成后的动作选择优先复用 `references/shared/flow-snippets.md` 中的 `completion-actions` 模板

## 每步流程

### 0. 存档（Step 模式）

每步代码变更完成且验证通过后，建立 1 个存档。详见 `references/principles/checkpoint-mechanism.md`。

**输出格式**：

```text
💾【存档】{业务摘要}#{序号} → {hash}
```

### 0.5 执行前快照闸门（强制）

每个 Step 开始前，按 `references/principles/checkpoint-mechanism.md` 的“执行前快照闸门”执行。

- 逐步执行：每个 Step 为独立执行段，每次“继续”重新触发闸门
- 信任模式：整个连续执行为一个执行段，仅首个 Step 前触发

闸门通过后才进入“开始声明”。

### 1. 开始声明

```text
现在实现: Step X/总数: [步骤名]
```

### 2. 上下文确认（强制）

- 必须读取 `current-steps.md`，包括：
  - 当前步骤
  - 关键决策
  - 模块策略
  - 测试等级
  - 观测驱动验证档位
  - 主观测面 / 备用观测面
  - 本步覆盖场景
  - 本步后台自动测试方式
- 若存在 `.autodev/current-test.md`，必须同步读取：
  - 场景矩阵状态
  - 待业务确认问题
  - GUI 自治验收状态
- 如发现计划与当前上下文不符 → 停下来问用户

### 2.5 Blast Radius 闸门（强制）

- 默认执行 `scripts/blast-radius-step.sh --step {N}`
- 该脚本会自动解析 `current-steps.md` 中本步的 `[Blast Radius: ... → ≤风险]`
- 只有当 `current-steps.md` 缺失或标记不合法时，才允许手工降级为 `scripts/blast-radius.py`
- 必须把最新报告写入 `.autodev/current-blast-radius.md`
- 必须在回执中说明：
  - 本步 Blast Radius 目标
  - 风险等级
  - 直接调用方 / 关键消费方
  - Gate 结论
- 若脚本结果高于计划阈值，或目标无法定位 → 停止本步，先回到计划层
- 若本步实际改动范围扩大，必须重跑后再继续写代码

### 3. 改动声明

```text
📋 改动范围:
- 文件: [列出]
- 函数 / 模块: [列出]
- Blast Radius: [.autodev/current-blast-radius.md / 风险等级 / Gate]
- 覆盖场景: [列出]
```

### 4. 执行改动（增量可测原则）

- 遵守模块策略：代码写入 `current-steps.md` 指定的目标文件，不随意换文件
- 复用检查：写新代码前，先确认 `module-registry` 里有没有能用的
- 增量可测：本步必须产出可独立验证的模块 / 函数 / 组件
- 若真实触碰的文件 / 符号超出本步 Blast Radius 目标，必须先刷新报告再继续
- 同步测试资产：
  - 更新本步覆盖的行为场景
  - 若项目有 BDD 框架且该场景适合 `.feature`，同步更新 `.feature` / step definitions
  - 若为大测试，同步更新 `current-test.md`
- 若本步命中 GUI-capable task，必须写明 GUI executor 与 `visual_mode`
- 若本步命中 GUI-capable task，必须先创建或更新 `.autodev/current-gui-test.js`，并显式写出“当前改动文件/模块 -> GUI case”对应关系
- 若复用现有 GUI 脚本，必须先确认它与本步覆盖场景直接对应；不直接对应时，必须重写 `.autodev/current-gui-test.js`
- Web GUI 默认 headed；除非用户明确允许 headless，或当前环境无法展示浏览器
- 若当前步骤还不具备 GUI 联调条件，必须明确标记“GUI 暂不可执行”
- Log 使用统一 fingerprint: `[DEV-{主题}-Step{N}]`
- 只要本步影响运行行为，默认至少执行一轮 `L1 观测驱动验证`
- 本步若已接通 GUI，遵守“先当前层后端，再本步最小 GUI case”；最后一步再做功能级整体回归

### 5. How to Test（强制）

```text
⛔⛔⛔ 红线：禁止伪造测试结果 ⛔⛔⛔

AI 必须：
1. 真正执行后台自动测试命令
2. 展示命令和关键输出
3. 如实区分“已验证”“未触发”“暂不可执行”“待业务确认”
```

#### Step 5.1: 确认本步测试范围

AI 必须先说明：

```text
📊 本步测试范围
- 测试等级: [小测试 / 大测试]
- 覆盖场景: [S1, S2 ...]
- 观测驱动验证: [L1 / L2 / L3]
- 主观测面: [...]
- 备用观测面: [...]
- 当前层级: [后端规则 / API / 前端页面 / 联调]
- GUI 状态: [未触发 / 暂不可执行 / 可执行]
- GUI executor: [无 / Playwright / ...]
- GUI 主脚本: [.autodev/current-gui-test.js / 无]
- Blast Radius 报告: [.autodev/current-blast-radius.md]
- Blast Radius 入口: [scripts/blast-radius-step.sh / 手工降级]
- 可视化执行: [required / preferred / unavailable]
```

#### Step 5.2: 后台自动测试（默认执行）

无论简单还是复杂，只要本步有行为改动，都必须先执行后台自动测试。

```text
🗄️ 后端测试开始 - [BE-{任务指纹}-Step{N}-{场景ID或场景组}-{测试方式}] {scope=当前层 | layer=后端规则/API/集成 | level=L1/L2/L3}
🧪 后台自动测试
- 方式: [单测 / 集成 / 契约 / API smoke / CLI]
- 命令: [实际执行的命令]
- 结果: [通过 / 失败 / 无法执行]
- 证据:
  [粘贴关键输出]
```

#### Step 5.3: 观测驱动验证（默认执行）

只要本步有行为改动，都必须执行对应档位的观测驱动验证。

```text
🔎 观测对比验证
- 档位: [L1 / L2 / L3]
- 预期观测: [...]
- 实际观测: [...]
- 差异结论: [通过 / 失败 / 暂不可执行 / 待业务确认]
```

规则：

- 自动测试通过但观测结果与预期不符，仍视为本步未完成
- 若发现复杂逻辑、跨模块、状态机、异步、缓存、权限等风险点，可从 `L1` 升到 `L2`
- 用户无法直接看到的观测面，由 AI 优先自行采证；只有观测面不可达时，才请求用户补最小证据

#### Step 5.4: GUI 自治验收闭环

```text
GUI 自治验收:
1. 未触发
2. 暂不可执行（等待后续步骤接通）
3. 规划中（已命中 GUI-capable task）
4. 执行中
5. 已通过
6. 用户禁用 / Manual only
```

当状态为 `规划中` 或 `执行中` 时：

- 默认直接执行 GUI executor，不再停在“建议执行”
- 真正拉起 GUI executor 前，先输出 `🖥️ 前端GUI测试开始 - [GUI-{任务指纹}-Step{N}-{caseID}-{executor}-r{轮次}] {scope=主验证/supplemental | visual=headed/headless | gate=GUI}`
- GUI 主验证默认执行 `.autodev/current-gui-test.js`；若该文件与当前改动不直接对应，必须先重写后再运行
- 现有业务 E2E 脚本只能作为补充回归，不能替代 `.autodev/current-gui-test.js`
- Web GUI 默认选择 Playwright；其他 GUI 使用当前环境可用的 executor
- Web GUI 默认使用 headed Playwright；只有用户明确允许 headless 或环境不可见时，才允许退化为 headless
- Web GUI 可采用 `Script-first Playwright` 或 `Suite-first Playwright`；前者更适合本地快速闭环与自修复
- 执行时同步采集 evidence bundle：timeline / screenshot / console / network / page state / backend trace
- 若失败，进入“采证 → 修复 → 重跑同一 case”的自修复循环，最多 3 次
- 若最终状态为 `用户禁用` / `暂不可执行` / `Manual only`，且该链路仍需要开发者本地环境、私有控制台、真机或外部系统确认，则 Step 5.6 必须补 `🧭 开发者手测教程`
- GUI Gate 未满足前，不得结束本步

#### Step 5.5: 更新测试台账（如适用）

若本任务为大测试，必须更新 `.autodev/current-test.md`：

- 场景状态
- 本轮执行记录
- 待业务确认问题
- 剩余风险

#### Step 5.6: 输出测试回执（必须）

完整字段与输出格式统一以 `references/principles/test-verification.md` 为准。

Step 模式必须额外说清：

- 这是 Step 级增量验证，不是最终功能级验收
- 本步是否已接通 GUI
- 若已接通，跑的是哪一个最小 GUI case，以及它如何直接对应当前改动
- 功能级整体回归会在最后一步完成

若 `人工验收.状态 = 需要开发者手测`，紧跟输出：

```text
🧭 开发者手测教程
前置条件:
- [环境 / 账号 / 开关 / 构建方式]
操作步骤:
1. [Step 1]
2. [Step 2]
3. [Step 3]
每步预期:
- Step 1 → [...]
- Step 2 → [...]
- Step 3 → [...]
回传证据:
- [截图 / console / network / 产物路径 中的最小必要证据]
```

#### Step 5.7: 结果处理

- ✅ 测试通过 → 进入结束阶段
- ❌ 测试失败 → 修复后重试（最多 3 次）
- ❌ 观测失败 → 修复后重试（最多 3 次）
- ❌ GUI Gate 不满足 → 继续执行 GUI 自治验收，不能进入结束阶段
- ⚠️ 命令执行失败 → 如实报告环境问题
- ⚠️ 业务规则不清 → 停下来问用户，不能继续自判

### 6. 结束（强制等待）

```text
--- Step X/总数 完成 ---

✅ 已更新 current-steps.md
⏸️ 等待确认后继续下一步...

请确认本步结果，回复:
- "ok" / "确认" / "继续" → 进入下一步
- "问题" / "回退" → 我会处理
```

更新 `current-steps.md`: 🌀 → ✅

### 7. 绝对禁止 - 必须等待用户确认

```text
⛔ 无论任何情况，Step 结束后必须停下等待用户回复
⛔ 禁止自己判断“应该没问题”然后继续
⛔ 即使代码很简单，也必须等待确认
⛔ 禁止拿历史 GUI 脚本冒充本步的最小 GUI case
```

## 信任模式

用户说“信任模式”时：

- 可连续执行多步，无需每步确认
- 🎯 开始前建立里程碑「{任务}#信任起点」
- 整个任务完成后建立 1 个存档（非每步）
- 仍然必须输出每步的 `🧾 测试回执`
- 若命中 GUI-capable task：
  - 用户已预授权 → 直接执行
  - 未显式禁用 → 仍默认执行 GUI executor
- 遇到问题立即停止，按 `references/principles/checkpoint-mechanism.md` 的读档模块展示存档列表
- 完成后统一报告所有改动，并询问是否合并 / 推送

## 最后一步特殊流程

```text
🧹 清理临时 log？

[1] 清理 - 删除所有 [DEV-{主题}-*] log
[2] 保留为生产观测 - 改为 [BASE-{模块名}]，精简为关键步骤
[3] 全部保留 - 保持原样（调试用）
```

## 任务完成收尾

```text
1. 输出最终测试回执（强制；若命中人工验收 fallback，必须附 `🧭 开发者手测教程`）
2. 自动更新文档（project-map / module-registry）
3. 若存在 current-test.md，同步更新最终状态
4. 建立存档（按 checkpoint-mechanism）
5. 报告剩余风险 / 待业务确认项
6. 询问是否建立里程碑「{任务}#完成」
7. 询问是否合并到集成分支、是否推送
```

## 任务完成后选项

```text
━━━━━━━━━━━━━━━━━━━━
✅ 任务"[任务名]"已完成，共执行 [N] 步

🌿 工作分支: [分支名]
📍 存档: 💾 [hash]「[指纹]」
━━━━━━━━━━━━━━━━━━━━
📌 下一步:
[1] 合并到 {集成分支} 并推送
[2] 合并到 {集成分支}（不推送）
[3] 继续开发
[4] 仅推送工作分支（便于创建 PR）
[5] 继续补测试资产（进入 auto-dev-team/tester 流程）
[6] 清理代码（进入 auto-dev-team/cleanup 流程）
[0] 结束（暂不合并）
━━━━━━━━━━━━━━━━━━━━
```

## 失败处理

```text
如果本步执行失败:
1. 立即停止
2. 报告: 失败原因 + 已改动文件 + 当前测试状态
3. 按 checkpoint-mechanism 的读档模块展示存档列表，让用户选择回退目标
```

## 途中微任务

当用户在 Step 执行中途发起其他请求：

```text
📒 auto-dev-team - 微任务 @Step{N}
[简述要做什么]

→ 直接执行 → 后台自动测试 → 输出测试回执 → 完成
```

边界：

- 若“微任务”需要 >30 行代码或 >2 文件 → 建议完成当前 Step 后单独处理
