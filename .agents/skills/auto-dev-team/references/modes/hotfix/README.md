# Hotfix 模式 (紧急修复)

> 适用: 线上出问题、紧急、需要快速止血 | 原则: 先止血后复盘，最小改动 | 产出: postmortem [HOTFIX]

⚠️ 若本次故障位于 GUI 链路，执行验证前必须读取 `references/principles/gui-autonomous-loop.md`。

## 核心原则

```
先止血，后复盘
最小改动，快速恢复
```

## 流程

### 0. 版本保护

- 💿 修复前（强制）：按 `references/principles/checkpoint-mechanism.md` 的"执行前快照闸门"执行。用户确认方案后、第一行代码写入前，必须通过闸门。
- 💾 修复完成且验证通过后：建立 1 个存档。详见 `references/principles/checkpoint-mechanism.md`。

### 1. 快速定位
```
用户: [描述紧急问题]
      [报错信息]

AI:   1. 跳过深度分析
      2. 直接定位出错位置
      3. 提出最小改动方案
      
      4. ⭐ 按 `references/principles/critique.md` 的模式集成流程执行自动会诊（紧急也不跳过）
         传递：【用户原始问题描述】+ 问题、最小修复方案
      5. 等待用户选择执行哪一个
```

### 1.5 Blast Radius 快速止血评估（强制）

```text
AI:   在第一行修复代码前，运行 `scripts/blast-radius.py`
      目标: 本次止血文件 / 符号 / 原始故障路径
      输出: 风险等级、直接调用方、原始回归入口、Gate 结论

      若结果 = 🔴 且无法缩小到单点止血:
      - 明确说明风险
      - 让用户确认是否继续临时止血
```

### 2. 快速修复
```
AI:   0. 💿 执行前快照闸门（强制）
         - 必须输出 "💿 已保护" 或 "💿 闸门通过" 后才能继续
         - 规则见 references/principles/checkpoint-mechanism.md
      0.5 Blast Radius 闸门（强制）
      1. 执行最小改动 (插入 log: [HOTFIX-{问题}])
      2. "⚠️ 这是临时止血，非根治"
      3. How to Test
         - 若执行后台 smoke / API / CLI 验证，先输出 `🗄️ 后端测试开始 - [BE-HOTFIX-{问题}-{场景}-{方式}] {scope=止血验证 | layer=API/CLI/smoke | level=L1}`
         
         过滤 `[HOTFIX-{问题}]` 应看到:
         → [HOTFIX-{问题}] 修复点: xxx
         → [HOTFIX-{问题}] 验证: xxx
```

若本次故障位于 GUI 链路：

```text
GUI 止血验证:
- 真正拉起 GUI executor 前，先输出 `🖥️ 前端GUI测试开始 - [GUI-HOTFIX-{问题}-{caseID}-{executor}-r{轮次}] {scope=主验证 | visual=headed/headless | gate=GUI}`
- 默认执行 GUI executor 复现原故障路径
- 证据至少保留 screenshot / console / network / 关键操作时间线
- 止血后必须重跑原 GUI case，确认症状消失
- 若 GUI Gate 未满足，只能声明“已止血到当前层”，不能说“整条用户链路已恢复”
```

### 3. 事后补票 (强制)
```
AI:   1. 自动写入 postmortem.md (标记 [HOTFIX])
         输出: "📝 已自动更新: postmortem.md - [HOTFIX] Bug-YYYY-MM-DD-00X"
      2. "建议后续创建 Debug 任务彻底排查"
      3. 清理 [HOTFIX-*] log (临时诊断用)
```

## 与 Debug 区别

| | Hotfix | Debug |
|---|--------|-------|
| 目标 | 止血 | 根治 |
| 分析 | 跳过 | 深入 |
| 方案 | 最小改动 | 完整修复 |
| 时间 | 分钟级 | 按需 |

## 修复完成后选项

```
📍 当前: 已临时止血，修复了"[问题简述]"
⚠️ 这是临时方案，建议后续彻底排查
📌 下一步:
[1] 深入排查（进入 auto-dev-team/debug 流程）- 找到根因，做彻底修复
[2] 查看 postmortem - 确认 [HOTFIX] 记录内容
[3] 开发新功能（进入 auto-dev-team/architect 流程）
[0] 结束
```
