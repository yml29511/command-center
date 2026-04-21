# 当前任务

创建时间: YYYY-MM-DD HH:mm

## 精炼需求

[一句话需求]

## 关键决策 (防遗忘，每步执行前必读)

- **复用**: [要用的现有组件]
- **抽象决策**: [是否抽象成通用 Utility]
- **影响范围**: [会改哪些文件]
- **边界处理**: [异常情况怎么办]
- **测试等级**: [小测试 / 大测试]
- **测试台账**: [无 / .autodev/current-test.md]
- **Blast Radius 策略**: [强制 / 手工降级]
- **Blast Radius 深度**: [1 / 2 / 3]
- **Blast Radius 当前报告**: [.autodev/current-blast-radius.md]
- **观测驱动验证**: [L1 / L2 / L3]
- **GUI 自治验收**: [未触发 / 默认执行 / 暂不可执行 / Manual only]
- **GUI executor**: [无 / Playwright / ...]
- **可视化执行**: [required / preferred / unavailable]
- **主观测面**: [...]
- **备用观测面**: [...]
- **Log 标识**: [DEV-{主题}]

## 计划 (每步必须增量可测)

- Blast Radius 标记格式:
  ` [Blast Radius: path/to/file::symbol → ≤🟡] `
  多目标用 `,` / `;` / `|` 分隔；Step 执行默认由 `scripts/blast-radius-step.sh` 自动解析

- [ ] 🌀 Step 1: xxx [可测产出: yyy] [覆盖场景: S1, S2] [后台自动测试: zzz] [Blast Radius: file::symbol → ≤🟡] [观测驱动验证: L1] [GUI: Playwright / 不触发] [主观测面: ...]
- [ ] 🌀 Step 2: xxx [可测产出: yyy] [覆盖场景: S3] [后台自动测试: zzz] [Blast Radius: file::symbol → ≤🟡] [观测驱动验证: L2] [GUI: 暂不可执行 / Manual only] [主观测面: ...]
- [ ] 🌀 Step 3: xxx [可测产出: yyy] [覆盖场景: S4] [后台自动测试: zzz] [Blast Radius: file::symbol → ≤🔴] [观测驱动验证: L3] [GUI: Playwright / 桌面 driver] [主观测面: ...]

⚠️ 每步必须产出可独立验证的模块 + 观测计划，禁止积攒到最后验证

## 执行记录

### Step 1
- 状态: 🌀待执行 / ✅完成 / ❌失败
- 覆盖场景:
- 改动文件: 
- Blast Radius:
  - 目标:
  - 报告:
  - 风险等级:
  - 直接调用方:
  - Gate 结论:
- 后台自动测试:
- 观测对比验证:
  - 档位:
  - 主观测面:
  - 预期观测:
  - 实际观测:
  - 差异结论:
- GUI 自治验收:
  - 状态:
  - Executor:
  - 可视化执行:
  - 关键用例:
  - 证据:
  - 修复轮次:
  - Gate 结论:
- 测试回执:
- 剩余风险:

### Step 2
- 状态: 🌀待执行
- 覆盖场景:
- 改动文件: 
- Blast Radius:
  - 目标:
  - 报告:
  - 风险等级:
  - 直接调用方:
  - Gate 结论:
- 后台自动测试:
- 观测对比验证:
  - 档位:
  - 主观测面:
  - 预期观测:
  - 实际观测:
  - 差异结论:
- GUI 自治验收:
  - 状态:
  - Executor:
  - 可视化执行:
  - 关键用例:
  - 证据:
  - 修复轮次:
  - Gate 结论:
- 测试回执:
- 剩余风险:

---
*最后更新: YYYY-MM-DD HH:mm*
