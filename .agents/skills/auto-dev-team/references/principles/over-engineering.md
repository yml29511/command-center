# 禁止过度设计原则

> ⛔ 过度设计检查已并入 `references/principles/critique.md`。本文件保留为兼容入口。

## 定义

过度设计 = 添加 PM 没要求的额外功能；这不包括必要的代码抽象。

## 最小自检

1. 这个能力是用户明确提出的，还是我觉得“应该有”？
2. 如果用户没提，我能否在不实现的情况下仍交付本任务？

若答案偏向“我觉得应该有”，先停下来问用户。

详细审查项见 `references/principles/critique.md`，抽象判断见 `references/principles/abstraction-rules.md`。
