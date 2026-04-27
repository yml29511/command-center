# 多Excel文件写入钉钉电子表格 Skill

将多个Excel文件数据自动写入钉钉电子表格，支持全量JSON模式和URL模式，自动合并多文件数据并分批写入。

## 功能特性

- ✅ 支持全量JSON模式（sheetData字段）
- ✅ 支持URL模式（fileUrl字段，自动下载解析）
- ✅ 多文件数据自动合并（以第一个文件表头为准）
- ✅ 数据自动清洗（转字符串、移除换行符、截断超长文本）
- ✅ 全量覆盖模式（清空旧数据后写入新数据）
- ✅ 智能分批写入（每批100行，批次间等待2秒）
- ✅ 写入后自动验证
- ✅ 纯Python实现，无需dws-cli
- ✅ 使用钉钉文档MCP直接操作电子表格

## 环境要求

- Python 3.9+
- 主要使用Python标准库
- openpyxl（可选，URL模式需要，支持动态安装）

## 使用方法

### 基本用法（命令行参数）

```bash
python skill_write_excel_to_table.py \
  --input-json '[{"fileName":"report.xlsx","sheetData":[["Name","Age"],["Alice","25"]]}]'
```

### 从stdin传入

```bash
echo '[{"fileName":"report.xlsx","sheetData":[["Name","Age"],["Alice","25"]]}]' | \
  python skill_write_excel_to_table.py
```

### 输入格式示例

#### 全量JSON模式（推荐）

```json
[
  {
    "fileName": "report1.xlsx",
    "sheetData": [
      ["Name", "Age", "City"],
      ["Alice", "25", "Beijing"],
      ["Bob", "30", "Shanghai"]
    ]
  },
  {
    "fileName": "report2.xlsx",
    "sheetData": [
      ["Name", "Age", "City"],
      ["Charlie", "28", "Guangzhou"]
    ]
  }
]
```

#### URL模式

```json
[
  {
    "fileName": "report1.xlsx",
    "fileUrl": "https://example.com/report1.xlsx"
  },
  {
    "fileName": "report2.xlsx",
    "fileUrl": "https://example.com/report2.xlsx"
  }
]
```

## 工作原理

1. **解析输入** - 识别JSON模式或URL模式
2. **获取数据** - JSON模式直接使用sheetData，URL模式下载并解析Excel
3. **合并数据** - 以第一个文件表头为准，纵向拼接所有数据行
4. **数据清洗** - 转字符串、移除换行符、截断超长文本（>500字符）
5. **MCP初始化** - 初始化连接并预热（get_range A1:A1）
6. **清空表格** - 填充10000×26空值数组清空旧数据
7. **分批写入** - 每批100行，批次间等待2秒
8. **验证写入** - 读取数据确认写入成功

## 技术实现

- 使用 **钉钉文档MCP HTTP API** 直接操作电子表格
- MCP配置已内置，无需额外配置
- 使用标准库 `urllib` 进行HTTP请求
- SSL证书验证已处理，适应各种网络环境
- 支持openpyxl动态安装（URL模式）

## 配置信息

### MCP连接信息（已内置）

```python
MCP_BASE_URL = "https://mcp-gw.dingtalk.com/server/aa6f2a5ec195aa1315c94be4f461bc432f38aa33c568f277a387863cd93e9a55"
MCP_KEY = "acbbd49834425c06878fd68d2a66b1ae"
```

### 目标表格信息（已内置）

```python
NODE_ID = "ydxXB52LJq7lrZejSQgQQEpQWqjMp697"
SHEET_ID = "Sheet1"
```

## 错误处理

- **输入格式错误** - 详细提示JSON解析错误位置
- **URL下载失败** - 提示检查URL可访问性
- **openpyxl不可用** - 提示使用全量JSON模式
- **MCP调用失败** - 自动重试，详细错误日志
- **写入验证失败** - 提示检查表格权限

## 文件清单

| 文件 | 说明 |
|------|------|
| `SKILL.md` | Skill说明文档（标准格式，给AI看的） |
| `skill_write_excel_to_table.py` | 主脚本（核心逻辑） |
| `README.md` | 本文件（项目说明） |

## License

Apache-2.0
