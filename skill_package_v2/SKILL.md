# Skill: 多Excel文件写入钉钉电子表格

## 概述
使用钉钉 MCP HTTP API 直接操作电子表格。支持从 fileUrl 下载 Excel 文件并解析写入。
纯 Python 标准库实现，**零外部依赖**。

## 执行方式

### 第一步：保存脚本
将下方【完整脚本代码】章节中的 Python 代码**完整保存**为文件 `skill_write_excel_to_table.py`

### 第二步：执行脚本
```bash
python3 skill_write_excel_to_table.py --input-json '<上游传入的JSON>'
```

## 输入格式
上游传入 JSON 数组，每个元素包含 fileName 和 fileUrl：
```json
[{"fileName":"xxx.xlsx","fileUrl":"https://..."}]
```

## 功能特性
- 从 fileUrl 下载 Excel 文件，纯标准库解析（zipfile + xml.etree）
- 写入前自动探测并清空旧数据（探测范围最大55000行，安全余量5000行）
- 动态分批写入（250行/批@20列），MCP调用自动重试
- 支持多文件合并写入
- 断点信息和进度百分比显示

## 注意事项
1. **必须使用下方的完整脚本代码**，不要自行编写替代脚本
2. 不需要安装任何第三方库（不需要 openpyxl、requests 等）
3. MCP 连接参数已硬编码在脚本中，无需额外配置
4. 如果脚本文件已存在，直接执行即可，无需重新保存

## 完整脚本代码

```python
#!/usr/bin/env python3
"""
Skill: 多Excel文件写入钉钉电子表格
使用钉钉 MCP HTTP API 直接操作电子表格

功能：
  1. 支持全量JSON模式（sheetData字段）和URL模式（fileUrl字段）
  2. 多文件数据合并（以第一个文件表头为准）
  3. 数据清洗（转字符串、移除换行符、截断超长文本）
  4. 清空旧数据后分批写入（每批100行）
  5. 写入验证确保数据真正写入

用法：
  python skill_write_excel_to_table.py --input-json '[{"fileName":"xxx","fileUrl":"xxx"}]'
  或
  echo '[{"fileName":"xxx","sheetData":[[...]]}]' | python skill_write_excel_to_table.py

依赖：
  - Python 3.9+（标准库：urllib, json, ssl, sys, argparse, time, re, zipfile, xml, io, tempfile, os）
  - 纯标准库实现，无需安装任何第三方依赖
"""

import json
import sys
import argparse
import re
import ssl
import time
import tempfile
import os
import zipfile
import xml.etree.ElementTree as ET
from io import BytesIO
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

# ============ MCP 配置 ============

MCP_BASE_URL = "https://mcp-gw.dingtalk.com/server/19bfa43f1b1d997b96851c2e9ba6f2ba49c2664396d3d04138a4b526b5ecac04"
MCP_KEY = "ecbd57e6981f54a7b86081e54975beee"
MCP_URL = f"{MCP_BASE_URL}?key={MCP_KEY}"

# ============ 表格配置 ============

NODE_ID = "a9E05BDRVQRkezKGCyxj30zoJ63zgkYA"
SHEET_ID = "Sheet1"

# ============ 常量 ============

BATCH_SIZE = 100
MAX_ROWS = 50000
MAX_COLS = 26  # A-Z
MAX_TEXT_LENGTH = 500


# ============ MCP API 调用 ============

def mcp_call(tool_name: str, arguments: dict, timeout: int = 120, max_retries: int = 2) -> dict:
    """
    调用 MCP 工具（tools/call 方法）
    支持自动重试机制，只重试网络/超时错误
    """
    for attempt in range(max_retries + 1):
        payload = {
            "jsonrpc": "2.0",
            "method": "tools/call",
            "params": {
                "name": tool_name,
                "arguments": arguments
            },
            "id": 1
        }

        data = json.dumps(payload).encode('utf-8')

        req = Request(
            MCP_URL,
            data=data,
            headers={
                "Content-Type": "application/json",
                "Accept": "application/json"
            },
            method="POST"
        )

        # 创建 SSL 上下文
        ssl_context = ssl.create_default_context()
        ssl_context.check_hostname = False
        ssl_context.verify_mode = ssl.CERT_NONE

        try:
            with urlopen(req, timeout=timeout, context=ssl_context) as resp:
                result = json.loads(resp.read().decode('utf-8'))

            if "error" in result and result["error"]:
                # 参数错误不重试
                return {"status": "error", "error": result["error"]}

            content = result.get("result", {}).get("structuredContent", {})

            if content.get("isError") or content.get("status") == "error":
                # API返回的错误不重试
                return {"status": "error", "error": content.get("error", {}).get("message", "Unknown error")}

            return {"status": "success", "data": content.get("data", {}), "summary": content.get("summary", "")}

        except HTTPError as e:
            # HTTP错误不重试（通常是4xx客户端错误）
            return {"status": "error", "error": f"HTTP {e.code}: {e.reason}"}
        except URLError as e:
            # URL错误（网络问题）可以重试
            if attempt < max_retries:
                print(f"  MCP 调用失败（尝试 {attempt+1}/{max_retries+1}），3秒后重试...")
                time.sleep(3)
                continue
            return {"status": "error", "error": f"URL Error: {e.reason}"}
        except Exception as e:
            # 其他异常（包括超时）可以重试
            if attempt < max_retries:
                print(f"  MCP 调用失败（尝试 {attempt+1}/{max_retries+1}），3秒后重试...")
                time.sleep(3)
                continue
            return {"status": "error", "error": str(e)}


def mcp_initialize() -> dict:
    """
    初始化 MCP 连接（initialize 方法）
    """
    payload = {
        "jsonrpc": "2.0",
        "method": "initialize",
        "params": {},
        "id": 1
    }

    data = json.dumps(payload).encode('utf-8')

    req = Request(
        MCP_URL,
        data=data,
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json"
        },
        method="POST"
    )

    ssl_context = ssl.create_default_context()
    ssl_context.check_hostname = False
    ssl_context.verify_mode = ssl.CERT_NONE

    try:
        with urlopen(req, timeout=30, context=ssl_context) as resp:
            result = json.loads(resp.read().decode('utf-8'))

        if "error" in result and result["error"]:
            return {"status": "error", "error": result["error"]}

        return {"status": "success", "data": result.get("result", {})}

    except HTTPError as e:
        return {"status": "error", "error": f"HTTP {e.code}: {e.reason}"}
    except URLError as e:
        return {"status": "error", "error": f"URL Error: {e.reason}"}
    except Exception as e:
        return {"status": "error", "error": str(e)}


def mcp_get_range(node_id: str, sheet_id: str, range_address: str) -> dict:
    """读取表格指定范围"""
    return mcp_call("get_range", {
        "nodeId": node_id,
        "sheetId": sheet_id,
        "rangeAddress": range_address
    })


def mcp_update_range(node_id: str, sheet_id: str, range_address: str, values: list) -> dict:
    """更新表格指定范围"""
    return mcp_call("update_range", {
        "nodeId": node_id,
        "sheetId": sheet_id,
        "rangeAddress": range_address,
        "values": values
    })


# ============ Excel 下载和解析 ============

def download_excel(url: str) -> bytes:
    """
    下载 Excel 文件，返回文件字节内容
    """
    ssl_context = ssl.create_default_context()
    ssl_context.check_hostname = False
    ssl_context.verify_mode = ssl.CERT_NONE

    req = Request(url)
    req.add_header("User-Agent", "Mozilla/5.0")

    with urlopen(req, timeout=120, context=ssl_context) as resp:
        return resp.read()


def parse_xlsx_stdlib(file_bytes: bytes) -> list:
    """
    用标准库解析xlsx文件，返回二维数组 [[row1_col1, row1_col2, ...], ...]
    纯标准库实现，无需第三方依赖
    """
    zf = zipfile.ZipFile(BytesIO(file_bytes))

    # 1. 读取共享字符串表
    shared_strings = []
    try:
        ss_xml = zf.read('xl/sharedStrings.xml')
        ss_tree = ET.fromstring(ss_xml)
        ns = {'ns': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
        for si in ss_tree.findall('.//ns:si', ns):
            # 处理普通文本和富文本两种情况
            t = si.find('ns:t', ns)
            if t is not None and t.text:
                shared_strings.append(t.text)
            else:
                # 富文本：多个 r/t 元素拼接
                parts = []
                for r in si.findall('.//ns:t', ns):
                    if r.text:
                        parts.append(r.text)
                shared_strings.append(''.join(parts))
    except KeyError:
        pass  # 没有共享字符串表

    # 2. 读取第一个工作表
    sheet_xml = zf.read('xl/worksheets/sheet1.xml')
    sheet_tree = ET.fromstring(sheet_xml)
    ns = {'ns': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}

    rows_data = []
    for row in sheet_tree.findall('.//ns:sheetData/ns:row', ns):
        row_cells = {}
        for cell in row.findall('ns:c', ns):
            ref = cell.get('r')  # e.g. "A1", "B1"
            cell_type = cell.get('t', '')
            val_elem = cell.find('ns:v', ns)

            if val_elem is None or val_elem.text is None:
                value = ''
            elif cell_type == 's':  # shared string
                idx = int(val_elem.text)
                value = shared_strings[idx] if idx < len(shared_strings) else ''
            elif cell_type == 'b':  # boolean
                value = 'TRUE' if val_elem.text == '1' else 'FALSE'
            else:  # number or inline string
                value = val_elem.text or ''

            # 解析列号 (A=0, B=1, ..., Z=25, AA=26, ...)
            col_str = ''.join(c for c in ref if c.isalpha())
            col_idx = 0
            for c in col_str:
                col_idx = col_idx * 26 + (ord(c.upper()) - ord('A') + 1)
            col_idx -= 1  # 0-based
            row_cells[col_idx] = value

        if row_cells:
            max_col = max(row_cells.keys()) + 1
            row_list = [row_cells.get(i, '') for i in range(max_col)]
            rows_data.append(row_list)

    zf.close()

    # 3. 确保所有行列数一致（以最大列数为准）
    if rows_data:
        max_cols = max(len(r) for r in rows_data)
        for r in rows_data:
            while len(r) < max_cols:
                r.append('')

    return rows_data


def parse_excel(file_bytes: bytes) -> list:
    """
    解析 Excel 文件为二维数组
    返回: [[表头...], [数据行1...], [数据行2...], ...]
    纯标准库实现，无需第三方依赖
    """
    values = parse_xlsx_stdlib(file_bytes)

    # 转换为字符串
    result = []
    for row in values:
        row_data = [str(cell) if cell is not None else "" for cell in row]
        result.append(row_data)

    return result


# ============ 数据处理 ============

def normalize_datetime(value):
    """将特殊日期格式转换为 yyyy-mm-dd hh:mm:ss"""
    if not isinstance(value, str):
        return value

    # 匹配 "12H 40 15/04/2026" 格式 (HH"H" MM DD/MM/YYYY)
    m = re.match(r'^(\d{1,2})H\s*(\d{1,2})\s+(\d{1,2})/(\d{1,2})/(\d{4})$', value.strip())
    if m:
        hour, minute, day, month, year = m.groups()
        return f"{year}-{int(month):02d}-{int(day):02d} {int(hour):02d}:{int(minute):02d}:00"

    # 匹配 "15/04/2026" 格式 (DD/MM/YYYY，无时间)
    m = re.match(r'^(\d{1,2})/(\d{1,2})/(\d{4})$', value.strip())
    if m:
        day, month, year = m.groups()
        return f"{year}-{int(month):02d}-{int(day):02d}"

    return value


def clean_cell_value(value: any) -> str:
    """
    清洗单元格值：
    1. 转字符串
    2. 日期格式转换
    3. 移除换行符（\n, \r）
    4. 截断超长文本（>500字符）
    """
    text = str(value) if value is not None else ""
    # 日期格式转换
    text = normalize_datetime(text)
    # 移除换行符
    text = text.replace('\n', ' ').replace('\r', ' ')
    # 截断超长文本
    if len(text) > MAX_TEXT_LENGTH:
        text = text[:MAX_TEXT_LENGTH] + "..."
    return text


def clean_data(values: list) -> list:
    """
    清洗整个二维数组
    """
    return [[clean_cell_value(cell) for cell in row] for row in values]


def merge_files(files_data: list) -> list:
    """
    合并多个文件的数据
    以第一个文件的表头为准，后续文件跳过表头
    """
    if not files_data:
        return []

    # 第一个文件：表头 + 数据
    merged = list(files_data[0])

    # 后续文件：只取数据行（跳过第一行表头）
    for file_data in files_data[1:]:
        if len(file_data) > 1:
            merged.extend(file_data[1:])

    return merged


def get_column_letter(col_index: int) -> str:
    """
    将列索引（0-based）转换为列字母（A, B, C, ..., Z, AA, AB...）
    """
    result = ""
    col_index += 1  # 转换为 1-based
    while col_index > 0:
        col_index, remainder = divmod(col_index - 1, 26)
        result = chr(65 + remainder) + result
    return result


def detect_data_rows() -> int:
    """
    逐段探测实际数据的最大行数
    返回最后有数据的行号

    改进策略：
    1. 检查多列（A:T，20列）而非仅A列，避免漏掉A列为空但其他列有数据的行
    2. 使用连续空段阈值（连续3个1000行段为空才停止），避免中间有空行导致提前停止
    3. 记录所有数据段，取最大值
    """
    last_data_row = 0
    empty_segments = 0  # 连续空段计数
    MAX_EMPTY_SEGMENTS = 3  # 连续3个空段才认为数据结束
    DETECT_COLS = 20  # 检查A-T列（20列）

    for start in range(1, 55001, 1000):
        end = start + 999
        # 检查多列（A-T）而非仅A列
        range_addr = f"A{start}:{get_column_letter(DETECT_COLS - 1)}{end}"
        result = mcp_get_range(NODE_ID, SHEET_ID, range_addr)

        if result.get("status") != "success":
            print(f"    探测 {range_addr} 失败: {result.get('error')}")
            break

        values = result.get("data", {}).get("values", [])
        if not values:
            empty_segments += 1
            if empty_segments >= MAX_EMPTY_SEGMENTS:
                break
            continue

        # 找最后一个非空行
        segment_has_data = False
        for i, row in enumerate(values):
            if row and any(cell and str(cell).strip() for cell in row):
                last_data_row = max(last_data_row, start + i)
                segment_has_data = True

        # 重置或增加空段计数
        if segment_has_data:
            empty_segments = 0
        else:
            empty_segments += 1
            if empty_segments >= MAX_EMPTY_SEGMENTS:
                print(f"    连续{MAX_EMPTY_SEGMENTS}个空段，停止探测")
                break

    return last_data_row


def clear_table_in_batches(total_rows: int, num_cols: int) -> int:
    """
    分批清空表格
    返回成功清空的行数
    """
    CLEAR_BATCH = 500
    last_col = get_column_letter(num_cols - 1)
    cleared = 0
    for start in range(1, total_rows + 1, CLEAR_BATCH):
        end = min(start + CLEAR_BATCH - 1, total_rows)
        batch_rows = end - start + 1
        empty = [[""] * num_cols for _ in range(batch_rows)]
        range_addr = f"A{start}:{last_col}{end}"
        result = mcp_update_range(NODE_ID, SHEET_ID, range_addr, empty)
        if result.get("status") == "success":
            cleared += batch_rows
            print(f"  清空 {range_addr} 成功 ({cleared}/{total_rows})")
        else:
            print(f"  清空 {range_addr} 失败: {result.get('error')}")
        time.sleep(1)
    return cleared


# ============ 主流程 ============

def main():
    parser = argparse.ArgumentParser(description="多Excel文件写入钉钉电子表格")
    parser.add_argument("--input-json", help="输入JSON（文件数组）")
    parser.add_argument("--dry-run", action="store_true", help="预览模式，不实际执行")

    args = parser.parse_args()

    print("=" * 60)
    print("Skill: 多Excel文件写入钉钉电子表格")
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

    if not isinstance(input_data, list):
        print("❌ 输入数据必须是JSON数组")
        sys.exit(1)

    print(f"  输入文件数: {len(input_data)}")

    # Step 2: 识别模式并解析数据
    print("\n[Step 2] 解析Excel数据...")

    files_data = []
    url_mode_count = 0
    json_mode_count = 0
    content_mode_count = 0

    for i, file_info in enumerate(input_data):
        file_name = file_info.get("fileName", f"file_{i+1}")
        print(f"\n  文件 {i+1}: {file_name}")

        # 模式1: 全量JSON模式（sheetData字段）
        if "sheetData" in file_info:
            json_mode_count += 1
            sheet_data = file_info["sheetData"]
            if isinstance(sheet_data, list) and len(sheet_data) > 0:
                files_data.append(sheet_data)
                print(f"    模式: JSON模式, 行数: {len(sheet_data)}")
            else:
                print(f"    ⚠️ sheetData 为空或格式错误")

        # 模式2: fileContent模式（tab分隔文本）
        elif "fileContent" in file_info:
            content_mode_count += 1
            content = file_info["fileContent"]
            if not content or not content.strip():
                print(f"    ⚠️ fileContent 为空，跳过")
                continue
            lines = content.strip().split("\n")
            values = [line.split("\t") for line in lines if line.strip()]
            if values:
                files_data.append(values)
                print(f"    模式: fileContent(TSV), 行数: {len(values)}")
            else:
                print(f"    ⚠️ fileContent 解析后为空")

        # 模式3: URL模式（fileUrl字段）
        elif "fileUrl" in file_info:
            url_mode_count += 1
            file_url = file_info["fileUrl"]
            print(f"    模式: URL模式")
            print(f"    URL: {file_url[:60]}...")

            try:
                # 下载并解析 Excel
                file_bytes = download_excel(file_url)
                print(f"    下载成功: {len(file_bytes)} 字节")

                values = parse_excel(file_bytes)
                print(f"    解析成功: {len(values)} 行")

                files_data.append(values)

            except Exception as e:
                print(f"    ❌ 处理失败: {e}")
                continue
        else:
            print(f"    ⚠️ 未识别到有效数据（需要 sheetData 或 fileUrl 字段）")

    print(f"\n  模式统计: JSON模式={json_mode_count}, URL模式={url_mode_count}, fileContent模式={content_mode_count}")

    if not files_data:
        print("❌ 没有成功解析任何文件数据")
        sys.exit(1)

    # Step 3: 合并数据并清洗
    print("\n[Step 3] 合并与清洗数据...")

    all_rows = merge_files(files_data)
    print(f"  合并前行数: {sum(len(f) for f in files_data)}")
    print(f"  合并后行数: {len(all_rows)}")

    if len(all_rows) == 0:
        print("❌ 合并后数据为空")
        sys.exit(1)

    # 数据清洗
    all_rows = clean_data(all_rows)
    print(f"  数据清洗完成")

    # 确定列数
    num_columns = max(len(row) for row in all_rows) if all_rows else 1
    print(f"  列数: {num_columns}")

    if args.dry_run:
        print("\n[DRY RUN] 预览模式，不实际执行")
        print(f"  表头: {all_rows[0] if all_rows else 'N/A'}")
        print(f"  数据行数: {len(all_rows) - 1 if len(all_rows) > 1 else 0}")
        sys.exit(0)

    # Step 4: MCP 初始化与连接预热
    print("\n[Step 4] MCP 连接初始化...")

    result = mcp_initialize()
    if result.get("status") == "error":
        print(f"  ⚠️ 初始化警告: {result.get('error')}")
    else:
        print("  ✅ 初始化完成")

    # 连接预热
    print("\n[Step 5] 连接预热...")
    for attempt in range(3):
        result = mcp_get_range(NODE_ID, SHEET_ID, "A1:A1")
        if result.get("status") == "success":
            print(f"  ✅ 预热成功（尝试 {attempt + 1}）")
            break
        else:
            print(f"  ⚠️ 预热失败（尝试 {attempt + 1}/3）: {result.get('error')}")
            if attempt < 2:
                time.sleep(2)
    else:
        print("  ⚠️ 预热失败，继续执行...")

    # Step 5: 清空表格
    print("\n[Step 6] 清空表格...")

    # 新策略：逐段探测旧数据的实际行数
    print("  探测旧数据范围...")
    old_data_rows = detect_data_rows()
    print(f"  检测到旧数据行数: {old_data_rows}")

    # 清空范围 = max(旧数据行数, 新数据行数) + 5000（安全余量）
    # 增加余量从2000到5000，确保即使探测有误差也能清空所有旧数据
    new_data_rows = len(all_rows)
    clear_target_rows = max(old_data_rows, new_data_rows) + 5000
    # 确保清空范围不超过最大行数限制（55000行）
    clear_target_rows = min(clear_target_rows, 55000)
    print(f"  新数据行数: {new_data_rows}")
    print(f"  将清空范围: A1:{get_column_letter(num_columns - 1)}{clear_target_rows}")

    # 分批清空
    cleared_count = clear_table_in_batches(clear_target_rows, num_columns)
    print(f"  ✅ 清空完成，共清空 {cleared_count} 行")

    # 清空后验证：检查清空范围末尾几行确认确实为空
    print("  验证清空结果...")
    verify_start = max(1, clear_target_rows - 5)  # 检查最后5行
    verify_end = clear_target_rows
    verify_range = f"A{verify_start}:A{verify_end}"
    verify_result = mcp_get_range(NODE_ID, SHEET_ID, verify_range)

    if verify_result.get("status") == "success":
        verify_values = verify_result.get("data", {}).get("values", [])
        if verify_values:
            # 检查是否所有单元格都为空
            all_empty = all(
                not row or all(not cell or not str(cell).strip() for cell in row)
                for row in verify_values
            )
            if all_empty:
                print(f"  ✅ 验证通过：{verify_range} 已清空")
            else:
                print(f"  ⚠️ 验证警告：{verify_range} 仍有数据，可能需要重新清空")
                # 尝试再次清空这5行
                print(f"  尝试再次清空 {verify_range}...")
                empty_values = [[""] * num_columns for _ in range(verify_end - verify_start + 1)]
                retry_result = mcp_update_range(NODE_ID, SHEET_ID, f"A{verify_start}:{get_column_letter(num_columns - 1)}{verify_end}", empty_values)
                if retry_result.get("status") == "success":
                    print(f"  ✅ 重新清空成功")
                else:
                    print(f"  ⚠️ 重新清空失败: {retry_result.get('error')}")
        else:
            print(f"  ✅ 验证通过：{verify_range} 无数据")
    else:
        print(f"  ⚠️ 验证读取失败: {verify_result.get('error')}")

    # Step 6: 分批写入
    # 动态计算批次大小：目标每批5000个单元格
    CELLS_PER_BATCH = 5000
    batch_size = max(10, min(500, CELLS_PER_BATCH // num_columns))
    print(f"\n[Step 7] 分批写入数据（动态批次: {batch_size}行/批, {batch_size * num_columns}单元格/批）...")

    last_col = get_column_letter(num_columns - 1)
    success_count = 0
    fail_count = 0

    for batch_index in range(0, len(all_rows), batch_size):
        batch = all_rows[batch_index:batch_index + batch_size]
        start_row = batch_index + 1
        end_row = batch_index + len(batch)
        range_addr = f"A{start_row}:{last_col}{end_row}"
        batch_num = batch_index // batch_size + 1

        # 确保每行有相同列数
        normalized_batch = []
        for row in batch:
            if len(row) < num_columns:
                row = row + [""] * (num_columns - len(row))
            elif len(row) > num_columns:
                row = row[:num_columns]
            normalized_batch.append(row)

        result = mcp_update_range(NODE_ID, SHEET_ID, range_addr, normalized_batch)

        # 计算进度百分比
        progress = (batch_index + len(batch)) / len(all_rows) * 100

        if result.get("status") == "success":
            print(f"  批次 {batch_num}: {range_addr} → 成功 ({len(batch)}行) [{progress:.1f}%]")
            success_count += len(batch)
        else:
            print(f"  批次 {batch_num}: {range_addr} → 失败: {result.get('error')} [{progress:.1f}%]")
            fail_count += len(batch)
            # 记录断点信息
            print(f"    ⚠️ 断点信息: 已成功写入到第 {success_count} 行")
            print(f"    💡 可从第 {success_count + 1} 行重新开始写入")

        # 批次间等待（最后一批不等待）
        if batch_index + batch_size < len(all_rows):
            time.sleep(1)

    # Step 7: 验证写入
    print("\n[Step 8] 验证写入结果...")

    verify_rows = min(10, len(all_rows))
    verify_last_col = get_column_letter(min(num_columns, 20) - 1)  # 最多验证前20列
    verify_range = f"A1:{verify_last_col}{verify_rows}"

    result = mcp_get_range(NODE_ID, SHEET_ID, verify_range)
    if result.get("status") == "success":
        verify_data = result.get("data", {}).get("values", [])
        if verify_data and len(verify_data) > 0:
            print(f"  ✅ 验证成功，读取到 {len(verify_data)} 行数据")
            if len(verify_data) > 0 and len(verify_data[0]) > 0:
                print(f"  表头预览: {verify_data[0][:5]}...")
        else:
            print("  ⚠️ 验证警告: 未读取到数据")
    else:
        print(f"  ⚠️ 验证失败: {result.get('error')}")

    # Step 8: 结果汇总
    print("\n" + "=" * 60)
    print("处理完成")
    print("=" * 60)
    print(f"总数据行数: {len(all_rows)}")
    print(f"成功写入: {success_count}")
    print(f"失败: {fail_count}")

    if fail_count == 0:
        print("✅ 全部成功")
        sys.exit(0)
    else:
        print("⚠️ 部分失败")
        sys.exit(1)


if __name__ == "__main__":
    main()
```
