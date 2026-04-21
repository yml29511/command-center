# Changelog

## 1.1.0-zh-CN

### Added

- `Brainstorm` 模式与 `current-brainstorm.md`
- `current-flow.json`、`flowctl.sh` 与 current artefact 契约
- `brainstorm-review` 与 `quality-review`
- 交互式预发测试链路
- `release-pack.py` 与 `release-pack-selftest.sh`
- 预发测试会话草稿模板
- 防屎山快速检查

### Changed

- 推荐主路径升级为 `Brainstorm -> Architect -> Step -> Review`
- `current-*` 模板升级为带 flow metadata 的 active flow artefacts
- `Tester` 模式扩展为测试资产与交互式验证流程
- `path.md` 增加长期事实更新规则
- SQL 查询改为一次性整段输出，并按项目数据库方言生成
- README 结构优化，补充版本、分支与 Agent Quick Start

### Fixed

- `blast-radius-selftest.sh` 的工作目录问题
- 多个自测脚本与交互式预发测试链路的一致性问题
