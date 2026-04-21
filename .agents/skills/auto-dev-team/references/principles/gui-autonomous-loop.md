# GUI 自治验收闭环

> canonical GUI 执行文档。定义“识别 GUI 任务 -> 执行 use case -> 采集证据 -> 自修复 -> 重跑 -> 完成 gate”的统一方法。

## 目录

- 目标
- GUI-capable task 触发器
- GUI executor 选择
- Web GUI 的推荐实现
- Script-first Playwright 标准结构
- Script-first Playwright 推荐流程
- 三层断言（强制）
- 可视化执行策略
- GUI case matrix（强制）
- 证据包（evidence bundle）
- 标准流程
- GUI 测试启动标识（强制）
- 失败分类（建议统一）
- 自修复循环
- 跨技术栈复用
- 非 Web GUI 的类似做法
- Completion Gate
- 与观测驱动验证的关系
- fallback 规则
- 输出字段（建议统一）

## 目标

- 让 GUI 成为第一等公民，而不是后台自动测试后的可选附加项。
- 让 AI 自己进入界面、模拟人类操作、采集前后端证据并完成自修复。
- 让用户在条件允许时看到执行过程；做不到用户可见时，也必须留下可回放证据。

## GUI-capable task 触发器

命中以下任一条件时，默认进入 GUI 自治验收闭环：

- 页面、窗口、表单、弹窗、路由、菜单、列表、搜索筛选
- 登录 / 注册 / 支付 / 权限 / 会话 / 上传下载
- 任何“用户可点击、可输入、可见结果”的界面
- 用户显式提到“前端验收”“全链路”“从用户角度”“模拟操作”

未命中以上条件时，可不进入本闭环。

## GUI executor 选择

按“能真实模拟用户操作”优先选择：

1. Web GUI -> `Playwright`
2. Desktop / Electron / Tauri -> 当前环境可用的 GUI driver
3. 宿主插件 / 嵌入面板 -> 当前宿主可用的操作入口
4. 无自动化入口 -> 状态标记为 `Manual only`

要求：

- 必须在计划或测试回执中写明本轮 executor。
- Web 场景默认不要把 Playwright 写成“可选提示”；它是默认 executor。
- Web 场景默认不要静默 headless；除非用户明确允许 headless，或环境无法展示浏览器。

## Web GUI 的推荐实现

### Script-first Playwright（推荐）

对于浏览器可访问的 Web GUI，Skill 推荐把下面这种写法视为一等方案：

```text
node .autodev/current-gui-test.js
```

`.autodev/current-gui-test.js` 是当前任务的 GUI 主测试入口。它必须是**为当前步骤动态准备的脚本**，而不是直接借用旧业务脚本。

这个模式已经在真实项目中验证过，优点是：

- 启动快，适合本地快速闭环
- 容易 `headed` 可见执行，用户和 AI 都能看到浏览器过程
- 脚本可以自己启动服务、准备种子数据、创建临时环境
- 业务动作可抽成 helper，失败后更容易按 case 修复并重跑
- AI 更容易根据报错、网络、页面状态直接修 locator / timing / state 问题

### Suite-first Playwright（同样有效）

对于需要并行、统一报告、fixtures、CI 体系的项目，也可以使用：

```text
npx playwright test
```

Skill 不强制二选一。它只要求：

- Web GUI 的 executor 是 `Playwright`
- use case 真正被执行
- 证据包完整
- 失败后走“采证 -> 修复 -> 重跑同一 case”

## 当前 GUI 脚本契约（强制）

- GUI 主验证入口固定为 `.autodev/current-gui-test.js`。
- 运行前必须检查 `.autodev/current-gui-test.js` 是否直接对应当前改动：
  - 至少 1 个 case 直接覆盖当前改动引入的用户可见风险
  - case 中的页面、网络、后端副作用断言能映射到当前改动文件/模块
  - 脚本中的 boot / seed / helper 不依赖无关业务链路
- 若现有 `.autodev/current-gui-test.js` 残留旧任务内容，必须重写；⛔ 禁止直接沿用不对应的旧脚本。
- 仓库里的历史 GUI 脚本只能被 `.autodev/current-gui-test.js` 引用、裁剪或作为补充回归；不能跳过 `.autodev/current-gui-test.js` 直接执行并声称“当前改动已验收”。
- `.autodev/current-gui-test.js` 文件头必须写清：
  - 当前任务/Step 指纹
  - 当前改动文件/模块
  - 覆盖的 GUI case
  - 为什么这些 case 与当前改动直接对应

### 何时优先 Script-first

- 项目还在快速迭代期
- 关键链路不多，但需要尽快闭环
- 当前更重视“本地快速复现 + AI 自修复”而不是“CI 报表体系”
- 用户希望看到真实浏览器快速点击、快速验证

### 何时优先 Suite-first

- 用例很多，需要并行
- 团队希望统一 reporter / fixtures / trace 管理
- 重点是 CI 稳定执行，而不是单条链路的本地快速修复

## Script-first Playwright 标准结构

脚本式 GUI loop 推荐至少包含以下结构：

1. `boot`
   - 启动本地服务或连接已有环境
   - 等待 health check
   - 创建临时配置 / 临时库 / 临时账号
2. `seed`
   - 准备最小种子数据
   - 尽量让数据构造靠近业务，不靠脆弱的 UI 前置操作
3. `helpers`
   - 抽出登录、上传、筛选、跳转、打开详情等业务动作
   - 避免把脚本写成纯 selector 堆叠
4. `case runner`
   - 逐个执行 Happy / Negative / Boundary / Recovery case
   - 每个 case 都有清晰的前置条件、动作和断言
5. `assertions`
   - 页面断言：DOM、URL、文案、可见状态
   - 网络断言：关键请求、状态码、响应体、headers
   - 后端副作用断言：写库、文件、事件、任务状态、服务端证据
6. `receipt`
   - 输出通过/失败统计
   - 输出 evidence bundle 位置
   - 失败时让 AI 能直接进入修复循环

另外要求：

- Playwright 默认 `headless: false`
- 只有用户明确说“可以 headless”或环境确实不可见时，才允许改成 `headless: true`

## Script-first Playwright 推荐流程

```text
组装 use case matrix
-> 启动临时环境 / health check
-> 准备种子数据
-> 抽业务 helper
-> 跑 Happy / Negative / Boundary / Recovery
-> 每个 case 同时断言 page / network / backend side effect
-> 失败分类
-> 修复代码或测试资产
-> 重跑同一 case
-> 关键 case 通过后跑一轮最小 GUI 回归
```

## 三层断言（强制）

GUI case 不应只验证“按钮能点”或“页面上有字”。至少要覆盖以下三层中的适用项：

1. `page assertion`
   - URL、文案、弹窗、表单状态、列表项、禁用态、可见性
2. `network assertion`
   - 请求是否发出、参数是否正确、状态码、响应体、响应头
3. `backend side-effect assertion`
   - 数据库变化、文件生成、任务状态、日志指纹、事件发送、服务端 trace

若某个 GUI case 只验证了第一层，通常不够支撑“闭环通过”。

## 可视化执行策略

`visual_mode` 统一使用以下枚举：

- `required`：默认值；浏览器窗口应尽量直接展示给用户
- `preferred`：用户未明确要求观看，但环境可见时仍优先展示
- `unavailable`：当前环境无法把 GUI 过程直接展示给用户

规则：

- Web GUI 默认 `visual_mode=required`，并优先 headed 执行。
- 若用户明确允许 headless，可降级为 `preferred`。
- 若只能后台运行，必须把 `visual_mode` 标为 `unavailable`，并补足截图、trace、timeline 等可回放证据。
- 不能把“后台执行且无证据”说成“用户已看到过程”。

## GUI case matrix（强制）

每个 GUI-capable task 至少要有一组 GUI case matrix，最少覆盖：

- `Happy`
- `Negative` 或 `Boundary`
- 若涉及会话 / 权限 / 状态流转，再补 1 个恢复或拒绝场景

每个 case 至少包含：

- `前置条件`
- `操作步骤`
- `预期页面变化`
- `预期网络行为`
- `预期后端结果 / 副作用`
- `失败时优先采集的观测面`

此外，case matrix 必须至少有 1 个 case 与当前改动直接对应；若只有历史业务大回归 case，没有当前改动直连 case，视为矩阵不合格。

## 证据包（evidence bundle）

每轮 GUI 验收至少保留：

- `action_timeline`：点击、输入、跳转、等待点
- `screenshots`：关键节点截图
- `browser_console`：错误、警告、关键日志
- `network_trace`：关键请求、状态码、失败点
- `page_state`：DOM / URL / 关键元素状态摘要
- `backend_trace`：可关联的 request id / trace id / 服务端证据（如适用）

若项目支持 trace viewer / 视频 / HAR，可作为增强证据。

推荐配套模板：

- `assets/templates/current-gui-test.js`
- `assets/templates/gui-case-matrix.md`
- `assets/templates/gui-evidence-bundle.md`
- `assets/templates/playwright-script-loop.js`

## 标准流程

1. 判断当前任务是否为 GUI-capable task。
2. 选择 executor 与 `visual_mode`；Web GUI 默认 headed。
3. 创建或更新 `.autodev/current-gui-test.js`。
4. 组装 GUI case matrix，并检查 case 与当前改动的直接对应关系。
5. 先执行后台自动测试与观测驱动验证，确认底层行为可测。
6. 执行 GUI case，并同步采集 evidence bundle。
7. 若失败，先分类，再进入自修复循环：
   - 视觉问题
   - locator / 选择器问题
   - 交互问题
   - 页面状态问题
   - 网络问题
   - 后端问题
   - 环境问题
8. 修复后，必须重跑同一 case。
9. 当前改动直连 case 通过后，才允许追加历史业务 GUI 脚本作为补充回归。
10. 关键 case 通过后，执行一轮最小 GUI 回归。
11. 更新 `current-test.md` 或测试回执。

## GUI 测试启动标识（强制）

GUI 自治验收不是“准备执行”就算开始，而是**真正拉起 GUI executor** 的那一刻才算开始。

要求：

- 在启动 Playwright 或其他 GUI executor 前，必须先输出启动标识。
- 启动标识必须遵循 `references/principles/test-verification.md` 的统一启动标识协议。
- 启动标识必须能让人看懂这是哪一轮、哪一个 case、由什么 executor 在跑。
- 同一 case 的修复重跑应保留同一主指纹，只增加 `r2 / r3` 这类轮次后缀。
- 若执行的是补充回归脚本，启动标识中必须明确写出 `supplemental`，避免和当前改动主验证混淆。

统一格式：

```text
🖥️ 前端GUI测试开始 - [GUI-{任务指纹}-{Step|Feature}-{caseID}-{executor}-r{轮次}] {scope=主验证/supplemental | visual=headed/headless | gate=GUI}
```

推荐字段来源：

- `{任务指纹}`：当前任务、功能或修复摘要
- `{Step|Feature}`：Step 编号或 Feature 回归标识
- `{caseID}`：GUI case matrix 中的 case ID
- `{executor}`：如 `playwright`、`detox`、`appium`
- `{轮次}`：首次执行为 `r1`，重跑递增

## 失败分类（建议统一）

失败时至少归类到以下一项，禁止只写“Playwright 失败”：

- `locator`
  - 选择器不稳、元素定位错误、文案变化
- `timing`
  - 页面异步未稳定、等待点错误、动画/延迟导致断言过早
- `frontend_state`
  - 前端状态没切换、表单值不正确、会话未建立
- `network`
  - 请求没发出、参数错、接口报错、headers 不符
- `backend`
  - 写库失败、副作用未发生、服务端逻辑错误
- `environment`
  - 服务没起来、账号/种子数据缺失、浏览器能力缺失
- `test_asset`
  - 用例本身失真、等待条件过弱、脚本假设过期

推荐处理顺序：

1. 先判断是不是 `test_asset` 或 `environment`
2. 再判断是不是 `frontend_state` / `network`
3. 最后再归因到真正的后端问题

## 自修复循环

```text
GUI case 失败
-> 失败分类
-> 采集最小必要证据
-> 修复代码或测试资产
-> 重跑同一 case
-> 若通过则更新状态
-> 若仍失败则继续诊断
-> 超过上限则停止并报告
```

约束：

- 默认最多 3 轮。
- 不能跳过“重跑同一 case”直接宣布修复。
- 不能把 locator 问题、环境问题、业务规则问题混成一句“测试失败”。

## 跨技术栈复用

只要最终承载在浏览器里，后端语言和框架不是边界。以下场景都可以直接复用 `use case script + Playwright`：

- React / Vue / Angular / Svelte / Next.js / Nuxt
- Django / Flask / FastAPI + 模板或前端
- Rails / Sinatra
- Laravel / Symfony
- Spring Boot / JSP / Thymeleaf
- ASP.NET MVC / Razor / Blazor Server
- Phoenix LiveView / HTMX / Hotwire

典型 GUI use case：

- 登录成功 / 登录失败 / 会话过期
- 列表筛选 / 空结果 / 分页边界
- 上传成功 / 非法格式失败 / 上传后列表刷新
- 新建 / 编辑 / 删除 / 删除被阻止
- 下单 / 支付后跳转 / 订单详情 / 下载交付物
- 桌面 / 移动 Web / 微信内 H5 不同设备上下文

## 非 Web GUI 的类似做法

以下类型项目也适合“先定义用户旅程 -> 再写 GUI 脚本 -> 跑自动化 -> 按失败分类修复”的方法，只是 executor 不一定还是 Playwright：

- Electron
  - 可继续优先评估 Playwright / Electron 侧能力
- Tauri / 原生桌面
  - 保留同样的 use case 脚本思路，切换到桌面 driver
- React Native / 原生 iOS / Android
  - 保留同样的旅程脚本与证据包思路，executor 常见为 Detox / XCUITest / Espresso / Appium

Skill 的核心不是“所有 GUI 都必须用 Playwright”，而是：

- 先定义用户旅程
- 再执行真实 GUI use case
- 同时验证页面、网络和副作用
- 失败后修复并重跑同一 case

## Completion Gate

GUI-capable task 完成前，必须满足以下之一：

- `passed`：GUI case 已执行并通过
- `blocked`：当前步骤尚不具备 GUI 联调条件，且已说明阻塞点
- `disabled_by_user`：用户明确要求本轮不执行 GUI 自动验收
- `manual_only`：环境无自动化入口，且已提供开发者手测教程

若状态为以下任一，禁止宣称完成：

- `planned`
- `ready`
- `running`
- `failed`

## 与观测驱动验证的关系

- GUI 自治验收闭环负责“执行、回放、自修复”。
- 观测驱动验证负责“定义预期观测、解释差异、帮助定位根因”。
- 两者必须协同使用，不能互相替代。

## fallback 规则

以下情况允许不自动跑 GUI executor：

- 当前步骤尚未接通 GUI
- 当前环境无 GUI 自动化能力
- 用户明确禁用
- 关键观测面只能在真机、私有 IDE、第三方后台获取

但此时必须：

- 明确写出状态与原因
- 输出 `🧭 开发者手测教程`
- 在 `剩余风险` 中记录未执行的 GUI 场景

## 输出字段（建议统一）

```text
GUI 自治验收:
- 状态: [未触发 / 规划中 / 执行中 / 已通过 / 失败修复中 / 暂不可执行 / 用户禁用 / Manual only]
- 启动标识: [🖥️ 前端GUI测试开始 - ... / 无]
- Executor: [...]
- 可视化执行: [required / preferred / unavailable]
- 覆盖用例: [...]
- 证据: [timeline / screenshot / console / network / trace]
- 修复轮次: [0 / 1 / 2 / 3]
- Gate 结论: [允许完成 / 不允许完成]
```
