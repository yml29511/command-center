---
name: write-to-dingtalk-table
description: |
  将指定内容写入钉钉表格的指定单元格。
  触发词：写入钉钉表格、写入钉文档、测试写入、钉钉表格写入、update_range。
---

# Write to DingTalk Table

## 功能说明

通过钉钉文档 MCP 工具，将内容写入指定钉钉表格的 A1 单元格。

## 执行步骤

1. **确认 MCP 可用**：检查当前环境已配置钉钉文档 MCP。
2. **调用 MCP 工具**：直接调用 `update_range` 工具写入数据。

## MCP 工具调用参数

调用 `update_range`，传入以下参数：

- `nodeId`: `"Y1OQX0akWmzdBowLFvpwLAolVGlDd3mE"`
- `sheetId`: `"Sheet1"`
- `rangeAddress`: `"A1:A1"`
- `values`: `[["测试成功写入钉文档"]]`

## 示例

```
工具: update_range
参数:
  nodeId: Y1OQX0akWmzdBowLFvpwLAolVGlDd3mE
  sheetId: Sheet1
  rangeAddress: A1:A1
  values:
    - ["测试成功写入钉文档"]
```

## 注意事项

- 确保 MCP 连接正常，且对目标表格有写入权限。
- 写入将覆盖 A1 单元格的现有内容。
- 如需写入其他位置，修改 `rangeAddress` 和 `values` 即可。
