# FastTrack 模式 (快速修改)

> 适用: 改文案、调样式、修小问题 | 限制: ≤2文件, ≤30行 | 超限自动升级为 Architect

⚠️ 若当前改动命中 GUI-capable task，执行验证前必须读取 `references/principles/gui-autonomous-loop.md`。

## 目录

- 适用场景
- 流程
- 自动升级条件
- 熔断机制
- 执行完成后选项
- 范围超限时选项

## 适用场景

- 改文案
- 调样式
- 修小 bug
- 单点改动

## 流程

### 0. 版本保护

- 💿 改动前（强制）：按 `references/principles/checkpoint-mechanism.md` 的"执行前快照闸门"执行。用户确认方案后、第一行代码写入前，必须通过闸门。
- 💾 改动完成且验证通过后：建立 1 个存档。详见 `references/principles/checkpoint-mechanism.md`。

### 1. 范围检查
```
AI:   📍 范围检查:
      - 涉及文件: ≤2 ✅ / >2 ❌
      - 代码改动: ≤30行 ✅ / >30行 ❌
      
      ✅ 范围可控 → 直接执行
      ❌ 超出范围 → "改动较大，建议使用完整的开发流程"
```

### 1.5 快速方案 + 会诊（强制）

1. 输出快速方案（原计划）
2. 按 `references/principles/critique.md` 的模式集成流程执行自动会诊。
   传递：【用户原始请求】+ 快速方案。
3. 等待用户选择执行原计划 / 修订计划。

### 1.9 保留性快速检查（强制）

即使是快速通道，也必须在执行前确认：

```
AI:   📋 保留性确认:
      - 操作类型: 添加 / 修改 / 删除
      - 目标: [文件名/结构名]
      - 现有元素: [N 个]
      - 本次保留: 全部 ✅ / 部分 [列出删除项]
      
      ⛔ 若为"添加"操作，"删除项"必须为空
```

### 1.95 Blast Radius 快速闸门（强制）

```text
AI:   运行 `scripts/blast-radius.py --file ... --symbol ... --mode fasttrack --task ... --write`
      输出:
      - `💥 Blast-radius 开始 - [BR-...] {...}`
      - 风险等级
      - 直接调用方 / 引用方
      - 邻近测试
      - Gate 结论

      ⛔ 若 Blast Radius = 🔴 或目标无法定位 → 停止，升级为 Architect
```

### 2. 直接执行
```
AI:   0. 💿 执行前快照闸门（强制）
         - 必须输出 "💿 已保护" 或 "💿 闸门通过" 后才能继续
         - 规则见 references/principles/checkpoint-mechanism.md
      0.5 通过 Blast Radius 闸门（强制）
      1. 执行改动 (插入 log: [SHORT-{主题}])
      2. 输出改动摘要
      3. How to Test (简化版)
```

### 3. How to Test (简化版)
```
🈶 验证:
- 若执行后台自动测试 / API smoke / CLI 验证，先输出 `🗄️ 后端测试开始 - [BE-SHORT-{主题}-{场景}-{方式}] {scope=当前层 | layer=API/CLI/smoke | level=L1}`
- 过滤 `[SHORT-{主题}]` 应看到: [关键 log 输出]
- 操作 [xxx]: [预期结果]
```

若当前改动命中 GUI-capable task：

```text
GUI 自治验收:
- 真正拉起 GUI executor 前，先输出 `🖥️ 前端GUI测试开始 - [GUI-SHORT-{主题}-{caseID}-{executor}-r{轮次}] {scope=主验证 | visual=headed/headless | gate=GUI}`
- 默认执行 GUI executor（Web 默认 Playwright）
- 优先可视化执行；做不到用户可见时，必须保留 screenshot / trace / console / network 证据
- 若 GUI case 失败，先修复再重跑同一 case，最多 3 次
- GUI Gate 未满足前，不能宣称本次 FastTrack 完成
```

若当前改动无法由 AI 完成自动验证（如 Figma 插件、私有控制台、复杂交互、真机 / 外设）：

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

### 4. 完成清理
```
改动生效后，清理 [SHORT-*] log
```

## 自动升级条件

以下情况自动升级为 Architect 模式:
- 涉及 >2 个文件
- 需要新建文件
- 涉及接口变更
- 可能影响其他模块
- Blast Radius = 🔴 或影响范围超出原计划

## 熔断机制

```
执行过程中发现:
- 改动越来越大 → 立即停止
- 影响范围超预期 → 立即停止
- 报告: "改动范围较大，建议使用完整的开发流程"
```

## 执行完成后选项

```
📍 当前: 已完成"[改动简述]"，改动了 [N] 个文件
📌 下一步:
[1] 继续小改（继续 auto-dev-team/fasttrack 流程）
[2] 开发新功能（进入 auto-dev-team/architect 流程）- 开始较大的新功能
[3] 清理代码（进入 auto-dev-team/cleanup 流程）- 顺便清理相关冗余代码
[0] 结束
```

## 范围超限时选项

```
📍 当前: 改动范围较大 (涉及 [N] 个文件 / [原因])
📌 下一步:
[1] 完整流程（进入 auto-dev-team/architect 流程）- 先做可行性评估
[2] 缩小范围 - 只做其中一部分: [列出可拆分的子任务]
[0] 取消
```
