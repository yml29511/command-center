# 路径清单机制 (path.md)

> 📍 所有项目环境、部署、运行入口、Git 路径信息的唯一真相来源。Skill 自身的策略阈值不写在这里，放到 `.autodev/autodev-config.json`。

## 机制说明

**每个项目必须有 `.autodev/path.md`**，记录所有与项目相关的固定路径和配置。

这是"环境配置的单一真相来源"，避免路径信息分散在各处。

## 必须包含的内容

| 分类 | 示例内容 |
|------|----------|
| **环境地址** | 本地、预发、生产的访问地址和端口 |
| **服务器路径** | 项目部署目录、日志目录、数据库路径 |
| **运行与观测入口** | 启动方式、日志入口、控制台入口、观测命令 |
| **GUI 执行入口** | GUI executor、script-first / suite-first 命令、trace/screenshot 产物入口、测试账号 |
| **Nginx 配置** | 配置文件路径、SSL 证书路径 |
| **Git 配置** | 远程仓库地址、分支策略、commit 规范 |
| **数据库** | 连接字符串模板、备份路径 |
| **第三方服务** | API 端点、控制台地址、文档链接 |
| **常用命令** | 部署、重启、备份等命令速查 |

## Git 路径与分支配置

`path.md` 中的 Git 配置供版本保护机制使用，详见 `references/principles/checkpoint-mechanism.md`。

Skill 策略阈值职责划分：

- `.autodev/path.md`：路径、环境、部署、Git 事实
- `.autodev/autodev-config.json`：会诊阈值、版本保护策略、日志开关等 skill 行为配置

## 引用规则

| 文档 | 必须包含 |
|------|----------|
| `.autodev/project-map.md` | 头部引用 `📍 环境路径详见 .autodev/path.md` |
| `.autodev/context-snapshot.md` | 头部引用 `📍 环境路径详见 .autodev/path.md` |

## AI 读取规则

以下操作**必须先读取 `.autodev/path.md`**：

- 部署相关操作
- Git commit/push 操作
- 环境配置修改
- 运行时路径排查
- 日志路径定位
- 控制台 / 观测入口定位
- GUI executor / script-first / headed 运行入口定位
- Playwright / 桌面 driver / trace viewer / evidence bundle 入口定位
- Nginx 配置修改
- 数据库操作
- 任何涉及服务器路径的操作

## 自动检测与创建

进入任何模式时，AI 必须：

1. 检查 `.autodev/path.md` 是否存在
2. 不存在时，使用 `assets/templates/path.md` 模板创建
3. 确认 `.git/info/exclude` 包含 `.autodev/`（由 write-preflight 统一处理）
4. 输出: `📄 已创建: .autodev/path.md（使用模板初始化，请填写实际配置）`

## 模板位置

`assets/templates/path.md`

## 维护规则

| 时机 | 动作 |
|------|------|
| 环境变更时 | 更新 path.md |
| 新增服务时 | 添加到 path.md |
| 新增运行入口 / 观测入口时 | 更新 path.md |
| 新增 GUI executor / 可视化执行入口时 | 更新 path.md |
| 新增 script-first Playwright 或 evidence bundle 路径时 | 更新 path.md |
| 路径变更时 | 同步更新 path.md |
| 任务完成后 | 检查是否涉及路径变更 |

### `path.md` 更新规则

- `path.md` 只写长期事实，不写临时会话信息
- 用户提供环境/路径信息时，先比对 `path.md`
- 新值缺失则新增，值变化则更新，值相同不重复写
- 临时地址、试用值、当前轮专用值只在会话里使用，不落盘

## 与其他文档的关系

```
.autodev/path.md (环境路径)
    ↑ 引用
.autodev/context-snapshot.md (项目快照)
    ↑ 引用
.autodev/project-map.md (架构地图)
```

这三个文档互相引用，形成完整的项目认知体系。
