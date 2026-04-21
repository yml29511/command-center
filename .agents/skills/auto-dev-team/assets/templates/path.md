# 项目路径清单

> ⚠️ 此文档记录项目所有固定路径和配置。部署、配置相关操作必须先读此文档。
> Skill 的策略阈值不写在这里，统一放在 `.autodev/autodev-config.json`。

## 目录

- 环境地址
- 服务器路径
- 运行与观测入口
- GUI 自治验收入口
- Nginx 配置
- Git 配置
- 数据库
- 第三方服务
- 常用命令速查

## 环境地址

| 环境 | 地址 | 备注 |
|------|------|------|
| 本地开发 | `http://localhost:3000` | |
| 预发环境 | `https://staging.example.com` | |
| 生产环境 | `https://www.example.com` | |

## 服务器路径

| 项目 | 路径 |
|------|------|
| 项目部署目录 | `/var/www/项目名` |
| 日志目录 | `/var/log/项目名` |
| 配置文件 | `/etc/项目名/config.json` |
| 数据目录 | `/var/data/项目名` |
| 备份目录 | `/var/backups/项目名` |

## 运行与观测入口

| 名称 | 类型 | 启动方式 | 查看方式 | 用途 |
|------|------|----------|----------|------|
| web-ui | `browser_console` | `pnpm dev` / `npm run dev` | 浏览器控制台 / Playwright console | 前端交互与页面脚本 |
| gui-executor | `browser_console` / `network_trace` | `npx playwright test --headed` / 对应 GUI driver 命令 | 可视化窗口 / trace viewer / GUI 日志 | GUI 自治验收闭环 |
| api-server | `process_stdout` | `pnpm dev:api` / `uvicorn ...` | 终端输出 | 后端逻辑与请求处理 |
| worker-log | `app_log_file` | - | `tail -f logs/worker.log` | 异步任务、队列、定时任务 |
| api-trace | `network_trace` | `curl` / Playwright / 浏览器 Network | 请求参数、状态码、响应 | 接口链路排查 |
| test-runner | `test_runner_output` | `pnpm test` / `pytest -q` | 测试命令输出 | 自动测试与失败定位 |
| artifact-check | `artifact_snapshot` | `node -e` / `python -c` / 自定义脚本 | 文件、数据库、DOM、JSON 快照 | 验证副作用与结果产物 |

## GUI 自治验收入口

| 项目 | 值 |
|------|-----|
| 默认 GUI executor | `Playwright` / `桌面 driver` / `manual_only` |
| script-first 命令 | `node agent_test/playwright/foo.ui.test.js` |
| suite-first 命令 | `npx playwright test --headed` |
| evidence bundle 路径 | `.autodev/temp/gui/` / `playwright-report/` / 自定义路径 |
| 测试账号 / 种子数据 | `[请填写]` |
| 用户可见执行限制 | `[无 / 远端环境无法开窗 / 仅本地可见]` |
| 常用设备上下文 | `[Desktop Chrome / iPhone / Android / WeChat UA / ...]` |

### GUI loop 约定

- Web GUI 若已有 `node xxx.ui.test.js`，优先记录为 `Script-first Playwright`
- 记录至少 1 条 headed 命令和 1 条 headless/CI 命令
- 记录 evidence bundle 的落盘路径
- 记录测试账号、种子数据、环境开关获取方式
- 记录是否支持用户可见执行，以及限制条件

## Nginx 配置

| 项目 | 路径/值 |
|------|---------|
| 配置文件 | `/etc/nginx/sites-available/项目名.conf` |
| SSL 证书 | `/etc/letsencrypt/live/域名/` |
| 访问日志 | `/var/log/nginx/项目名-access.log` |
| 错误日志 | `/var/log/nginx/项目名-error.log` |

### 常用 Nginx 配置项

```nginx
# 示例配置
server {
    listen 443 ssl;
    server_name example.com;
    
    ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;
    
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

## Git 配置

| 项目 | 值 |
|------|-----|
| 远程仓库 (origin) | `git@github.com:用户名/仓库名.git` |
| 备用仓库 (gitee) | `git@gitee.com:用户名/仓库名.git` |

### 分支策略（auto-dev-team 专用）

| 配置项 | 值 | 说明 |
|--------|-----|------|
| `integration_branch` | `main` | 功能完成后合并到的目标分支 |
| `protected_branches` | `main, master, production, release/*` | 受保护分支，AI 不会直接在上面操作 |
| `integration_mode` | `merge_allowed` | `merge_allowed`=个人开发（可本地合并），`pr_only`=团队协作（只推工作分支创建PR，拒绝本地合并） |
| `push_default` | `false` | 是否默认推送到远程（建议 false，由用户确认后推送） |

### 分支命名规范

- `main` / `master`: 生产环境代码
- `dev` / `develop`: 开发分支
- `feature/*`: 功能分支
- `hotfix/*`: 紧急修复分支
- `autodev/*`: AI 工作分支（auto-dev-team 自动创建）

### Milestone Tag 说明

`milestone/*` tag 仅供本地回退使用，请勿通过 `git push --tags` 推送到远程。

### Commit 规范

```
「{指纹}」{类型}: {一句话描述}

- 改动1
- 改动2
```

**指纹**：≤10 字业务功能摘要，如 `会员登录#01`  
**类型**：`feat` | `fix` | `refactor` | `perf` | `docs` | `chore`

## 数据库

| 项目 | 值 |
|------|-----|
| 类型 | SQLite / MySQL / PostgreSQL |
| 本地路径 | `./data/database.db` |
| 生产路径 | `/var/data/项目名/database.db` |
| 备份路径 | `/var/backups/项目名/db/` |

### 连接字符串模板

```
# SQLite
sqlite:./data/database.db

# MySQL
mysql://user:password@localhost:3306/dbname

# PostgreSQL
postgresql://user:password@localhost:5432/dbname
```

## 第三方服务

| 服务 | 控制台/端点 | 文档 |
|------|------------|------|
| 阿里云 OSS | `https://oss.console.aliyun.com` | [文档](https://help.aliyun.com/product/31815.html) |
| 有赞开放平台 | `https://console.youzanyun.com` | [文档](https://doc.youzanyun.com/) |
| Let's Encrypt | - | [文档](https://letsencrypt.org/docs/) |

## 常用命令速查

```bash
# 部署
ssh user@server "cd /var/www/项目名 && git pull && npm install && pm2 restart all"

# 查看日志
ssh user@server "tail -f /var/log/项目名/app.log"

# 观察特定接口
curl -i http://localhost:3000/api/example

# 查看测试输出
pytest -q

# 重启服务
ssh user@server "pm2 restart 项目名"

# 备份数据库
ssh user@server "/var/www/项目名/scripts/backup-db.sh"

# SSL 证书续期
ssh user@server "certbot renew --quiet"
```

---
*最后更新: YYYY-MM-DD*
*更新者: [功能/原因]*
