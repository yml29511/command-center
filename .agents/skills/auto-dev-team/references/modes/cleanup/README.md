# Cleanup 模式 (代码清理)

> 适用: 删除没用的代码、清理冗余 | 类型: 死代码/冗余依赖/临时代码

## AI 必须主动读取

进入此模式时，AI 必须主动读取以下文件（无需用户提供）：
- `.autodev/project-map.md` - 了解项目结构

## 清理类型

### 1. 死代码清理
```
AI:   扫描未使用的:
      - 未调用的函数
      - 未使用的变量
      - 未使用的 import
      - 注释掉的代码块
      
      📋 待清理:
      | 文件 | 行号 | 类型 | 内容 |
      |------|------|------|------|
      
      "确认删除？"
```

### 2. 冗余依赖清理
```
AI:   检查依赖文件 (package.json / requirements.txt / go.mod / Cargo.toml):
      - 未使用的依赖
      - 重复的依赖
      - 可合并的依赖
```

### 3. 临时代码清理
```
AI:   扫描:
      - TODO/FIXME 注释
      - 调试语句 (console.log / print / fmt.Println)
      - 调试断点 (debugger / breakpoint())
      - 临时 hardcode
```

## 流程

```
1. 扫描 → 输出清单
2. 用户确认范围
3. 💿 执行前快照闸门（强制）
   - 必须输出 "💿 已保护" 或 "💿 闸门通过" 后才能继续
4. 🧭 Blast Radius 删除证明（强制）
   - 对候选删除文件 / 符号执行 `scripts/blast-radius.py ... --mode cleanup --write`
   - 重点确认：直接调用方、reverse import chain、邻近测试
   - 若仍有活跃调用方，禁止继续删除
5. 逐项清理
6. 验证
7. 建立存档（详见 references/principles/checkpoint-mechanism.md）
8. 自动更新 module-registry.md (如删除了已注册组件)
```

## 安全规则

- 删除前必须确认无调用
- 删除前必须保留 Blast Radius 报告
- 批量删除需用户二次确认
- 版本保护机制确保可回退（详见 `references/principles/checkpoint-mechanism.md`）

## 清理完成后选项

```
📍 当前: 已清理 [N] 项，删除了 [文件/代码行数] 
📌 下一步:
[1] 继续清理（继续 auto-dev-team/cleanup 流程）- 扫描其他类型的冗余代码
[2] 开发新功能（进入 auto-dev-team/architect 流程）
[3] 重构代码（进入 auto-dev-team/refactor 流程）- 进一步整理代码结构
[0] 结束
```
