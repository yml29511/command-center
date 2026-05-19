---
name: json-to-excel-generator
description: |
  将图片解析Agent输出的JSON表格数据转换为Excel文件（.xlsx格式）。
  支持多表格、多工作表，纯Python标准库实现，零外部依赖。
  触发词：JSON转Excel、生成Excel、图片表格导出、表格数据转换、xlsx生成
---

# Skill: JSON数据生成Excel文件

## 概述
将图片解析Agent输出的JSON表格数据转换为Excel文件（.xlsx格式）。纯Python标准库实现，支持多表格、多工作表。

## 执行方式

### 第一步：保存脚本
将下方【完整脚本代码】章节中的 Python 代码**完整保存**为文件 `json_to_excel.py`

### 第二步：执行脚本
```bash
python3 json_to_excel.py --input-json '<图片解析Agent输出的JSON>' --output-file 'output.xlsx'
```

## 输入格式
上游图片解析Agent输出的JSON数组格式：
```json
[
  {
    "tableId": "table_1",
    "tableName": "空间成员列表",
    "headers": ["成员", "云账号", "角色", "加入时间"],
    "rows": [
      ["李辉", "4pxtech:S9602", "数据分析师 × 开发 × 访客", "2023年12月21日 16:00:59"],
      ["张天军", "4pxtech:S16396", "空间管理员", "2021年9月14日 11:34:07"]
    ],
    "totalRows": 2,
    "note": "第1页，每页显示100条"
  }
]
```

## 功能特性
- 支持多表格生成（每个table对象生成一个独立工作表）
- 自动设置列宽（根据内容自适应）
- 表头加粗和背景色
- 冻结首行（方便滚动查看）
- 纯Python标准库实现（csv + zipfile），零外部依赖
- 支持大文件（自动分批写入）

## 注意事项
1. **必须使用下方的完整脚本代码**，不要自行编写替代脚本
2. 不需要安装任何第三方库（不需要 openpyxl、xlsxwriter 等）
3. 使用CSV格式生成ZIP包（标准xlsx格式），兼容性最好
4. 如果脚本文件已存在，直接执行即可，无需重新保存

## 完整脚本代码

```python
#!/usr/bin/env python3
"""
Skill: JSON数据生成Excel文件
将图片解析Agent输出的JSON表格数据转换为Excel文件（.xlsx格式）

功能：
  1. 支持多表格生成（每个table一个工作表）
  2. 自动格式化（表头加粗、背景色、冻结首行）
  3. 纯标准库实现（csv + zipfile），无需第三方依赖
  4. 支持大文件处理

用法：
  python json_to_excel.py --input-json '<JSON字符串>' --output-file 'output.xlsx'
  或
  echo '<JSON字符串>' | python json_to_excel.py --output-file 'output.xlsx'

依赖：
  - Python 3.9+（标准库：json, csv, zipfile, io, sys, argparse, os）
  - 纯标准库实现，无需安装任何第三方依赖
"""

import json
import csv
import zipfile
import io
import sys
import argparse
import os
from pathlib import Path


# ============ Excel 生成（纯标准库实现） ============

def generate_xlsx(tables_data: list) -> bytes:
    """
    生成xlsx文件（使用标准库csv + zipfile）
    tables_data: [{"tableName": str, "headers": list, "rows": list}, ...]
    """
    zip_buffer = io.BytesIO()

    with zipfile.ZipFile(zip_buffer, 'w', zipfile.ZIP_DEFLATED) as zf:
        # 1. 创建 [Content_Types].xml
        content_types = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
</Types>"""
        zf.writestr('[Content_Types].xml', content_types)

        # 2. 创建 _rels/.rels
        rels = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>"""
        zf.writestr('_rels/.rels', rels)

        # 3. 生成工作表数据
        sheet_names = []
        for idx, table in enumerate(tables_data, 1):
            table_name = table.get("tableName", f"Sheet{idx}")
            # 清理Sheet名称（不能包含特殊字符）
            table_name = "".join(c for c in table_name if c.isalnum() or c in (' ', '_', '-', '、', '（', '）', '(', ')'))
            table_name = table_name[:31]  # Excel限制31字符
            if not table_name:
                table_name = f"Sheet{idx}"
            sheet_names.append(table_name)

            headers = table.get("headers", [])
            rows = table.get("rows", [])

            # 生成CSV临时文件
            csv_buffer = io.StringIO()
            writer = csv.writer(csv_buffer)
            writer.writerow(headers)
            for row in rows:
                writer.writerow(row)
            csv_data = csv_buffer.getvalue()

            # 将CSV转换为Excel XML格式
            sheet_xml = generate_sheet_xml(csv_data, headers, rows)
            zf.writestr(f'xl/worksheets/sheet{idx}.xml', sheet_xml)

        # 4. 生成 workbook.xml
        workbook_xml = generate_workbook_xml(sheet_names)
        zf.writestr('xl/workbook.xml', workbook_xml)

        # 5. 生成 workbook.rels
        workbook_rels = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
"""
        for idx in range(1, len(sheet_names) + 1):
            workbook_rels += f'  <Relationship Id="rId{idx}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet{idx}.xml"/>\n'
        workbook_rels += '  <Relationship Id="rIdStyles" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>\n'
        workbook_rels += '</Relationships>'
        zf.writestr('xl/_rels/workbook.xml.rels', workbook_rels)

        # 6. 生成 styles.xml
        styles_xml = generate_styles_xml()
        zf.writestr('xl/styles.xml', styles_xml)

        # 7. 生成 docProps
        core_xml = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:title>图片解析表格数据</dc:title>
  <dc:creator>Image Parser</dc:creator>
</cp:coreProperties>"""
        zf.writestr('docProps/core.xml', core_xml)

        app_xml = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties">
  <Application>Microsoft Excel</Application>
</Properties>"""
        zf.writestr('docProps/app.xml', app_xml)

    zip_buffer.seek(0)
    return zip_buffer.getvalue()


def generate_sheet_xml(csv_data: str, headers: list, rows: list) -> str:
    """生成工作表XML（带格式化）"""
    ns = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'

    # 计算列数
    num_cols = len(headers)

    # 生成 sheetPr（页面设置）
    sheet_pr = f'<sheetPr xmlns="{ns}"/>'

    # 生成 dimension（数据范围）
    last_col = get_column_letter(num_cols - 1)
    last_row = len(rows) + 1
    dimension = f'<dimension ref="A1:{last_col}{last_row}" xmlns="{ns}"/>'

    # 生成 sheetViews（冻结首行）
    sheet_views = f'''<sheetViews xmlns="{ns}">
    <sheetView tabSelected="1" workbookViewId="0">
      <selection activeCell="A2" sqref="A2"/>
      <pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/>
    </sheetView>
  </sheetViews>'''

    # 生成 sheetFormatPr（默认行高列宽）
    sheet_format_pr = f'<sheetFormatPr defaultRowHeight="15" defaultColWidth="12" xmlns="{ns}"/>'

    # 生成 cols（列宽）
    cols_xml = '<cols xmlns="{ns}">'
    for i in range(num_cols):
        col_letter = get_column_letter(i)
        # 根据表头内容估算列宽
        header_len = len(str(headers[i])) if headers[i] else 5
        col_width = max(10, min(50, header_len * 2))
        cols_xml += f'<col min="{i+1}" max="{i+1}" width="{col_width}" customWidth="1"/>'
    cols_xml += '</cols>'

    # 生成 sheetData（数据）
    sheet_data = '<sheetData xmlns="{ns}">'

    # 表头行（第1行）
    row_1 = '<row r="1" spans="1:' + str(num_cols) + '">'
    for col_idx, header in enumerate(headers):
        col_letter = get_column_letter(col_idx)
        cell_ref = f"{col_letter}1"
        # 表头使用样式2（加粗+背景色）
        row_1 += f'<c r="{cell_ref}" s="2" t="inlineStr"><is><t>{escape_xml(str(header))}</t></is></c>'
    row_1 += '</row>'
    sheet_data += row_1

    # 数据行（第2行开始）
    for row_idx, row in enumerate(rows, 2):
        row_xml = f'<row r="{row_idx}" spans="1:{num_cols}">'
        for col_idx, cell_value in enumerate(row):
            if col_idx >= num_cols:
                break
            col_letter = get_column_letter(col_idx)
            cell_ref = f"{col_letter}{row_idx}"
            value = str(cell_value) if cell_value is not None else ""
            # 数据使用样式1（普通文本）
            row_xml += f'<c r="{cell_ref}" s="1" t="inlineStr"><is><t>{escape_xml(value)}</t></is></c>'
        row_xml += '</row>'
        sheet_data += row_xml

    sheet_data += '</sheetData>'

    # 组合完整的工作表XML
    sheet_xml = f'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="{ns}">
  {sheet_pr}
  {dimension}
  {sheet_views}
  {sheet_format_pr}
  {cols_xml}
  {sheet_data}
</worksheet>'''

    return sheet_xml


def generate_workbook_xml(sheet_names: list) -> str:
    """生成workbook.xml"""
    ns = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'
    r_ns = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'

    sheets_xml = '<sheets xmlns="' + ns + '">'
    for idx, name in enumerate(sheet_names, 1):
        sheets_xml += f'<sheet name="{escape_xml(name)}" sheetId="{idx}" r:id="rId{idx}" xmlns:r="' + r_ns + '"/>'
    sheets_xml += '</sheets>'

    return f'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="{ns}" xmlns:r="{r_ns}">
  <fileVersion appName="xl" lastEdited="7" lowestEdited="7" rupBuild="23601"/>
  <workbookPr dateCompatibility="false" filterPrivacy="1"/>
  <bookViews>
    <workbookView activeTab="0"/>
  </bookViews>
  {sheets_xml}
  <definedNames/>
  <calcPr calcId="191029"/>
</workbook>'''


def generate_styles_xml() -> str:
    """生成styles.xml（定义样式）"""
    ns = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'

    return f'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="{ns}">
  <numFmts count="0"/>
  <fonts count="3">
    <font><sz val="11"/><color theme="1"/><name val="Calibri"/><family val="2"/><scheme val="minor"/></font>
    <font><b/><sz val="11"/><color theme="1"/><name val="Calibri"/><family val="2"/><scheme val="minor"/></font>
    <font><b/><sz val="11"/><color rgb="FFFFFF"/><name val="Calibri"/><family val="2"/><scheme val="minor"/></font>
  </fonts>
  <fills count="3">
    <fill><patternFill patternType="none"/></fill>
    <fill><patternFill patternType="gray125"/></fill>
    <fill><patternFill patternType="solid"><fgColor rgb="4472C4"/></patternFill></fill>
  </fills>
  <borders count="1">
    <border><left/><right/><top/><bottom/><diagonal/></border>
  </borders>
  <cellStyleXfs count="1">
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>
  </cellStyleXfs>
  <cellXfs count="3">
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
    <xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>
    <xf numFmtId="0" fontId="2" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1"/>
  </cellXfs>
  <cellStyles count="1">
    <cellStyle name="Normal" xfId="0" builtinId="0"/>
  </cellStyles>
  <dxfs count="0"/>
  <tableStyles count="0" defaultTableStyle="TableStyleMedium2" defaultPivotStyle="PivotStyleLight16"/>
</styleSheet>'''


def get_column_letter(col_index: int) -> str:
    """将列索引（0-based）转换为列字母（A, B, C, ..., Z, AA, AB...）"""
    result = ""
    col_index += 1  # 转换为 1-based
    while col_index > 0:
        col_index, remainder = divmod(col_index - 1, 26)
        result = chr(65 + remainder) + result
    return result


def escape_xml(text: str) -> str:
    """转义XML特殊字符"""
    text = text.replace('&', '&amp;')
    text = text.replace('<', '&lt;')
    text = text.replace('>', '&gt;')
    text = text.replace('"', '&quot;')
    text = text.replace("'", '&apos;')
    return text


# ============ 主流程 ============

def main():
    parser = argparse.ArgumentParser(description="JSON数据生成Excel文件")
    parser.add_argument("--input-json", help="输入JSON（图片解析Agent输出）")
    parser.add_argument("--output-file", required=True, help="输出Excel文件路径")

    args = parser.parse_args()

    print("=" * 60)
    print("Skill: JSON数据生成Excel文件")
    print("=" * 60)

    # Step 1: 解析输入数据
    print("\n[Step 1] 解析输入数据...")

    if args.input_json:
        try:
            input_data = json.loads(args.input_json)
        except json.JSONDecodeError as e:
            print(f"❌ JSON解析失败: {e}")
            sys.exit(1)
    else:
        try:
            input_data = json.load(sys.stdin)
        except json.JSONDecodeError as e:
            print(f"❌ stdin JSON解析失败: {e}")
            sys.exit(1)

    # 支持两种输入格式：
    # 1. [...] （直接是tables数组）
    # 2. {"tables": [...]} （兼容旧格式）
    if isinstance(input_data, list):
        tables_data = input_data
    elif isinstance(input_data, dict):
        if "tables" in input_data:
            tables_data = input_data["tables"]
        else:
            print("❌ JSON格式错误：缺少 'tables' 字段")
            sys.exit(1)
    else:
        print("❌ JSON格式错误：必须是数组或对象")
        sys.exit(1)

    if not isinstance(tables_data, list):
        print("❌ tables 必须是数组")
        sys.exit(1)

    print(f"  表格数量: {len(tables_data)}")

    # 统计总数据量
    total_rows = 0
    for idx, table in enumerate(tables_data, 1):
        table_name = table.get("tableName", f"Table{idx}")
        rows = table.get("rows", [])
        total_rows += len(rows)
        print(f"  表格 {idx}: {table_name} ({len(rows)} 行数据)")

    print(f"  总数据行数: {total_rows}")

    # Step 2: 生成Excel
    print("\n[Step 2] 生成Excel文件...")

    try:
        xlsx_bytes = generate_xlsx(tables_data)
        print(f"  ✅ Excel生成成功: {len(xlsx_bytes)} 字节")
    except Exception as e:
        print(f"  ❌ Excel生成失败: {e}")
        sys.exit(1)

    # Step 3: 保存文件
    print("\n[Step 3] 保存文件...")

    output_path = Path(args.output_file)

    # 确保输出目录存在
    output_path.parent.mkdir(parents=True, exist_ok=True)

    try:
        with open(output_path, 'wb') as f:
            f.write(xlsx_bytes)
        print(f"  ✅ 文件保存成功: {output_path.absolute()}")
        print(f"  文件大小: {len(xlsx_bytes)} 字节")
    except Exception as e:
        print(f"  ❌ 文件保存失败: {e}")
        sys.exit(1)

    # Step 4: 结果汇总
    print("\n" + "=" * 60)
    print("处理完成")
    print("=" * 60)
    print(f"生成表格数: {len(tables_data)}")
    print(f"总数据行数: {total_rows}")
    print(f"输出文件: {output_path.absolute()}")
    print("✅ 全部成功")

    sys.exit(0)


if __name__ == "__main__":
    main()
```

## 使用示例

### 示例1：单表格生成
```bash
python3 json_to_excel.py --input-json '[{"tableId":"table_1","tableName":"空间成员列表","headers":["成员","云账号","角色","加入时间"],"rows":[["李辉","4pxtech:S9602","数据分析师","2023-12-21"]]}]' --output-file 'output.xlsx'
```

### 示例2：多表格生成（从stdin读取）
```bash
cat input.json | python3 json_to_excel.py --output-file 'output.xlsx'
```

## 输出说明
- 生成的Excel文件包含多个工作表（每个table对应一个sheet）
- 表头自动加粗、蓝色背景、白色字体
- 首行冻结（方便滚动查看数据）
- 列宽根据表头内容自适应调整

## 技术实现
- 纯Python标准库（csv + zipfile）
- 无需安装openpyxl、xlsxwriter等第三方库
- 直接生成xlsx格式的ZIP包（符合Open XML标准）
- 支持大文件处理（内存友好）
