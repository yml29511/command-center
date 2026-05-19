# BUA节点表格数据提取JSON输出格式标准

## 概述
BUA节点通过浏览器自动化直接提取网页表格数据，输出标准化的JSON数组格式，供下游节点（如Excel生成Skill）使用。

## 输出格式

### 基础格式（单个表格）

```json
[
  {
    "tableId": "table_1",
    "tableName": "空间成员列表",
    "sourceUrl": "https://dataworks.console.aliyun.com/...",
    "extractTime": "2026-05-18 16:10:45",
    "headers": ["成员", "云账号", "角色", "加入时间", "操作"],
    "rows": [
      ["4pxtech", "4pxtech", "空间管理员", "2020年5月12日 11:05:44", "所有者"],
      ["董闻(禾名)", "4pxtech:248630", "开发 × 运维", "2025年12月22日 17:27:12", "移除"],
      ["洪传校", "4pxtech:S16333", "数据分析师 × 开发 × 运维 × 部署 × 访客", "2025年11月18日 19:07:18", "移除"]
    ],
    "totalRows": 3,
    "currentPage": 1,
    "totalPages": 1,
    "note": "第1页，每页显示100条"
  }
]
```

### 多表格格式（多个表格）

```json
[
  {
    "tableId": "table_1",
    "tableName": "空间成员列表",
    "sourceUrl": "https://dataworks.console.aliyun.com/...",
    "extractTime": "2026-05-18 16:10:45",
    "headers": ["成员", "云账号", "角色", "加入时间", "操作"],
    "rows": [...],
    "totalRows": 100,
    "currentPage": 1,
    "totalPages": 1,
    "note": "第1页，每页显示100条"
  },
  {
    "tableId": "table_2",
    "tableName": "空间角色列表",
    "sourceUrl": "https://dataworks.console.aliyun.com/...",
    "extractTime": "2026-05-18 16:11:50",
    "headers": ["角色名称", "角色类型", "描述", "创建时间"],
    "rows": [...],
    "totalRows": 15,
    "currentPage": 1,
    "totalPages": 1,
    "note": "共15个角色"
  }
]
```

## 字段说明

### 表格级别字段

| 字段名 | 类型 | 必填 | 说明 | 示例 |
|--------|------|------|------|------|
| `tableId` | 字符串 | ✅ | 表格唯一标识，格式：`table_N` | `"table_1"` |
| `tableName` | 字符串 | ✅ | 表格名称（根据页面标题或上下文推断） | `"空间成员列表"` |
| `sourceUrl` | 字符串 | ✅ | 数据来源URL | `"https://..."` |
| `extractTime` | 字符串 | ✅ | 数据提取时间（格式：YYYY-MM-DD HH:mm:ss） | `"2026-05-18 16:10:45"` |
| `headers` | 数组 | ✅ | 表头数组，包含所有列名 | `["成员", "云账号", ...]` |
| `rows` | 二维数组 | ✅ | 数据行数组，每行是一个数组 | `[["值1", "值2"], ...]` |
| `totalRows` | 数字 | ✅ | 数据行数（不含表头） | `100` |
| `currentPage` | 数字 | ✅ | 当前页码 | `1` |
| `totalPages` | 数字 | ✅ | 总页数 | `1` |
| `note` | 字符串 |  | 备注信息（分页信息等） | `"第1页，每页显示100条"` |

### 数据行字段

- `rows` 中的每个元素是一个数组，代表一行数据
- 数组元素顺序必须与 `headers` 对应
- 空单元格使用空字符串 `""`
- 多值字段（如角色列）使用 `" × "` 分隔

## 特殊字段处理规则

### 1. 多值字段
如果单元格内有多个值（如角色列显示多个标签）：
```json
"数据分析师 × 开发 × 运维 × 部署 × 访客"
```

### 2. 时间格式
保持原始格式，不要转换：
```json
"2025年12月22日 17:27:12"
```

### 3. 操作列
保留操作按钮文字：
```json
"移除"
"编辑"
"查看"
```

### 4. 复选框列
如果表格第一列是复选框，**忽略该列**，不提取。

### 5. 空值处理
- 空白单元格 → `""`
- 无法识别的内容 → `"?"`

## 分页处理

### 单页表格
```json
{
  "currentPage": 1,
  "totalPages": 1,
  "note": "第1页，每页显示100条"
}
```

### 多页表格（合并输出）
```json
{
  "currentPage": 1,
  "totalPages": 3,
  "note": "第1-3页，每页显示100条，共250条数据"
}
```

**注意**：如果表格跨多页，BUA节点应该：
1. 逐页读取所有数据
2. 合并到一个 `rows` 数组中
3. 更新 `totalRows`、`totalPages`、`note` 字段

## 空数据格式

如果表格无数据：
```json
[
  {
    "tableId": "table_1",
    "tableName": "空间成员列表",
    "sourceUrl": "https://...",
    "extractTime": "2026-05-18 16:10:45",
    "headers": [],
    "rows": [],
    "totalRows": 0,
    "currentPage": 1,
    "totalPages": 0,
    "note": "无数据"
  }
]
```

## 完整示例

基于你提供的截图，标准输出示例：

```json
[
  {
    "tableId": "table_1",
    "tableName": "空间成员列表",
    "sourceUrl": "https://dataworks.console.aliyun.com/workspace/settings/member",
    "extractTime": "2026-05-18 16:10:45",
    "headers": ["成员", "云账号", "角色", "加入时间", "操作"],
    "rows": [
      ["4pxtech", "4pxtech", "空间管理员", "2020年5月12日 11:05:44", "所有者"],
      ["董闻(禾名)", "4pxtech:248630", "开发 × 运维", "2025年12月22日 17:27:12", "移除"],
      ["洪传校", "4pxtech:S16333", "数据分析师 × 开发 × 运维 × 部署 × 访客", "2025年11月18日 19:07:18", "移除"],
      ["周崇恩", "4pxtech:S32044", "数据分析师 × 开发 × 运维 × 部署 × 访客", "2025年12月4日 17:49:11", "移除"],
      ["冯嘉东", "4pxtech:10098496", "数据分析师 × 开发 × 运维 × 访客", "2025年11月11日 20:24:09", "移除"]
    ],
    "totalRows": 179,
    "currentPage": 1,
    "totalPages": 2,
    "note": "第1-2页，每页显示100条，共179条数据"
  }
]
```

## 使用注意事项

1. **必须是JSON数组** - 输出格式为 `[...]`，不要使用 `{tables: [...]}`
2. **不要包含Markdown标记** - 直接输出JSON，不要用 ` ```json ` 包裹
3. **不要包含解释性文字** - 只输出JSON，不要有其他文字
4. **确保UTF-8编码** - 支持中文字符
5. **数据完整性** - 确保所有行都提取完整，不要遗漏
6. **字段顺序一致** - `rows` 中的每个数组元素顺序必须与 `headers` 对应

## 下游兼容性

此格式与以下组件兼容：
- ✅ JSON转Excel生成Skill（`json_to_excel.py`）
- ✅ 钉钉表格写入Skill（`multi-excel-to-table-skill-v2`）
- ✅ 任何支持JSON数组的下游节点

## 错误处理

如果提取失败，输出：
```json
[
  {
    "tableId": "table_1",
    "tableName": "未知",
    "sourceUrl": "https://...",
    "extractTime": "2026-05-18 16:10:45",
    "headers": [],
    "rows": [],
    "totalRows": 0,
    "currentPage": 0,
    "totalPages": 0,
    "note": "提取失败：错误原因描述",
    "error": true
  }
]
```
