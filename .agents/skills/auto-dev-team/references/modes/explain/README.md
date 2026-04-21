# Explain 模式 (代码理解)

> 适用: 想理解某段代码怎么工作的、"这个XXX是怎么实现的？" | 产出: 调用链可视化

## 目录

- AI 必须主动读取
- 适用场景
- 流程 (单阶段)
- 输出原则
- 深入追问处理
- 与其他模式的边界
- 完成后选项
- 强制规则
- 与 Ask Mode 的区别

## AI 必须主动读取

进入此模式时，AI 必须主动查找并读取用户提到的功能相关文件（无需用户手动提供）。

## 适用场景

- 接手项目，学习代码
- 理解某个功能的实现逻辑
- Code Review 前快速了解
- 评估影响范围前先看调用关系

## 流程 (单阶段)

```
用户: 用户登录流程是怎么实现的？
      @LoginButton.tsx

AI:   🔥 auto-dev-team - Explain 已激活
      
      📊 [用户登录] 实现路径:
      
      入口: LoginButton.tsx:25
      ├─ onClick → handleLogin() @ auth.ts:45
      │  ├─ validateForm() @ validator.ts:12
      │  │  └─ checkEmail() + checkPassword()
      │  ├─ POST /api/login @ api.ts:78
      │  └─ onSuccess()
      │     ├─ saveToken() → localStorage
      │     └─ navigate('/dashboard')
      
      🔄 数据流转:
      email/password → 验证 → API请求 → token → 存储 → 跳转
      
      💡 一句话: 表单验证后调用登录API，成功则存token并跳转首页
      
      📂 核心文件:
      - auth.ts - 登录主逻辑
      - validator.ts - 表单验证规则
      - api.ts - API封装
```

## 输出原则

- **调用链深度 ≤3层** (太深引导用户追问具体函数)
- **总输出 ≤400字** (符合简洁标准)
- **只展示结构，不展开代码** (除非用户追问)
- **标注文件位置** (便于用户跳转查看)
- **关键分支点必须说明** (如 if/switch 的不同路径)

## 深入追问处理

```
用户: "validateForm 里面具体做了什么？"

AI:   📊 validateForm() 详细展开:
      
      位置: validator.ts:12-28
      
      ├─ checkEmail(email)
      │  → 正则验证格式
      │  → 返回 boolean
      ├─ checkPassword(password)  
      │  → 长度 ≥8
      │  → 包含数字+字母
      │  → 返回 boolean
      └─ 返回: { valid: boolean, errors: string[] }
      
      边界处理:
      - 空值 → 返回 "字段不能为空"
      - 格式错误 → 返回具体错误信息
```

## 与其他模式的边界

| 情况 | 用哪个模式 |
|------|-----------|
| 只想理解，暂不改动 | **Explain** |
| 理解后要新增功能 | Explain → Architect |
| 理解后要修 bug | Explain → Debug |
| 理解后要重构 | Explain → Refactor |
| 全项目架构理解 | **Survey** (不是 Explain) |

## 完成后选项

```
📍 当前: 已解释"[功能]"的实现路径
📌 下一步:
[1] 深入（继续 auto-dev-team/explain 流程）- 展开某个函数的内部实现: [列出可展开的函数]
[2] 开始开发（进入 auto-dev-team/architect 流程）- 基于理解开始功能开发
[3] 调试问题（进入 auto-dev-team/debug 流程）- 发现问题，需要调试
[4] 重构代码（进入 auto-dev-team/refactor 流程）- 发现代码异味，需要整理
[0] 结束
```

## 强制规则

- 必须输出可视化调用链 (用树状结构)
- 必须标注文件路径和行号
- 禁止粘贴大段代码 (只描述结构)
- 发现明显问题可提示，但不主动修复
- 超过3层调用 → 折叠细节，引导用户追问

## 与 Ask Mode 的区别

```
Ask Mode (Cursor 原生):
- 自由问答，格式不固定
- 适合概念性问题 "什么是闭包？"

Explain Mode (auto-dev-team):
- 标准化输出格式 (调用链可视化)
- 专注代码实现路径
- 适合 "这个功能怎么实现的？"
```
