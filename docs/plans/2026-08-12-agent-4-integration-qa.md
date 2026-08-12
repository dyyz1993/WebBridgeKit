# Next Phase Integration QA and Release Evidence Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 独立验证官方零配置首启、自托管网关导入和强离线包在同一集成版本中可用、安全、互不污染，并产出可重复运行的测试、截图和发布证据。

**Architecture:** 本任务不实现前三条功能，而从合并后的 `INTEGRATION_SHA` 建立独立 QA 分支；以协议测试、模块测试、UI journey、静态检查、崩溃扫描和人工设备清单分层验收。发现实现问题时用失败测试或精确报告回交对应负责人，不跨所有权直接修业务代码。

**Tech Stack:** XCTest/XCUITest, XcodeBuildMCP, shell verification scripts, Simulator screenshots, Markdown verification reports

---

## 任务身份

你是 WebBridgeKit 的独立集成测试、文档与回归负责人。你必须在模型 1–3 的提交都进入集成分支后开始。不要参与功能实现，不要“顺手”改 `Sources/`、`SuperApp` 业务代码或 `Server` 实现。

## 启动依赖和硬门槛

协调者必须提供：

```text
BASE_SHA=<模型1、2、3共同起点的待填写 SHA>
INTEGRATION_SHA=<包含模型1、2、3提交的待填写 SHA>
MODEL_1_COMMITS=<待填写>
MODEL_2_COMMITS=<待填写>
MODEL_3_COMMITS=<待填写>
```

若任一项缺失，停止并报告。不要从一个有未提交修改的共享目录直接测试。

1. 在独立 worktree/分支 `codex/next-phase-qa` 工作。
2. 确认 `git rev-parse HEAD == INTEGRATION_SHA`、`git status --short` 为空。
3. 完整阅读根目录 `AGENTS.md`、四份本阶段任务包和三位实现者的交接报告。
4. 完整阅读 XcodeBuildMCP skill；iOS build/test/run/screenshot 按 skill 执行。
5. 启动前记录模拟器型号、iOS 版本、Xcode 版本和当前 SHA。

## 文件所有权

允许新增或修改：

- `SuperAppUITests/NextPhaseAcceptanceTests.swift`（新建）
- `SuperAppUITests/NextPhaseAccessibilityTests.swift`（新建，确有必要时）
- `tools/verify-next-phase-acceptance.sh`（新建）
- `tools/run-release-gate.sh`（只接入已经稳定的新门禁）
- `tools/verify-module-availability-report.sh`（仅新增报告一致性检查）
- `docs/verification/next-phase-acceptance.md`（新建）
- `docs/verification/module-availability-verification.md`
- `docs/RELEASE_CHECKLIST.md`
- `docs/screenshots/**` 和 `build/reports/**`（验证产物；是否提交按仓库既有规则）

禁止修改：

- `Sources/**`
- `SuperApp/Sources/**`
- `Server/Sources/**`
- `AppTemplate/**`
- 模型 1–3 的实现测试，除非只是修明显的测试编译接线且先在报告说明
- 协议设计文档的语义

发现失败时：先保存命令、日志、截图、最小复现和归属；能用本任务新测试稳定复现则提交失败测试。不要跨界修复业务实现。

## Task 1：基线与差异审计

对 `INTEGRATION_SHA` 做只读审计：

```bash
git diff --stat <BASE_SHA>..INTEGRATION_SHA
git diff --name-only <BASE_SHA>..INTEGRATION_SHA
```

确认：

1. 模型 1 未改自托管/离线/AppTemplate 文件。
2. 模型 2 未改官方推送/离线/AppTemplate/Server 文件。
3. 模型 3 未改官方/自托管 UI/AppTemplate/Server 文件。
4. 新 public API 有测试和文档；不存在重复类型、两套状态源或无调用的占位实现。
5. `AppTemplate` 仍只依赖稳定 SDK 公共面，不包含官方产品服务、示例页或 gateway 默认值。

不符合时在报告中标为 BLOCKED，并列出确切文件和行，不继续掩盖冲突。

## Task 2：建立端到端 UI journey

新增 `NextPhaseAcceptanceTests.swift`，只使用稳定 accessibility identifiers 和测试注入，避免大量全屏 accessibility snapshot。

### Journey A：官方首次使用

1. 清空测试身份启动。
2. 首页直接可理解，不出现网关配置表单。
3. 点“启用通知”，用测试权限/APNs token 完成登记。
4. 推送地址变为可复制，普通和 Markdown 示例可生成。
5. 从测试推送进入 Inbox，再进入 Markdown 详情。
6. 审批 push 只打开待确认详情，未自动提交；必须有明确用户动作和重新校验状态。

### Journey B：自托管一次导入

1. 打开网关管理，粘贴与 QR 相同的合法 payload。
2. 先看到验证报告，确认前当前网关不变。
3. 确认后活动网关与应用列表更新。
4. 切换到不同 origin 后旧 permission grants 不出现。
5. 非 HTTPS、secret 字段或错误签名不会激活。

摄像头扫码只验证入口和解析同一 payload 的单元证据，不要求模拟器自动拍码。

### Journey C：强离线包

1. 本地服务在线时安装 fixture v1。
2. 打开 HTML app 并确认入口/资源加载。
3. 停止或阻断 fixture 网络、清空 WebKit cache，再次打开仍成功。
4. 在线尝试安装破损 v2，安装失败后仍启动 v1。
5. UI/诊断明确显示当前活动版本和更新失败，不出现空白 WebView。

如果可靠断网不适合 XCUITest，将安装/回滚放在集成测试，将 UI 只验证已安装包启动；报告必须区分两类证据。

## Task 3：协议与模块回归矩阵

至少运行并记录精确通过数：

```bash
bash scripts/services.sh start
bash scripts/services.sh verify
(cd Server && swift test)
bash tools/verify-message-types-v1.sh
bash tools/verify-approval-v1.sh
WBK_GATEWAY_URL=https://cloak.xbrowser.dev:5801 bash tools/verify-open-gateway.sh
bash tools/verify-strong-offline-package.sh
bash tools/run-cache-regression.sh
bash tools/run-jsbridge-regression.sh
bash tools/run-template-gate.sh
```

特别复核消息协议：普通、Markdown、验证码、二维码、图片、聊天、审批七类字段均能被 Inbox 和详情消化；未知字段保留兼容或明确忽略，不能导致崩溃。HTML/PWA 类型默认打开配置目标；敏感审批仍不由 push 参数授权。

## Task 4：视觉、可访问性和崩溃门禁

使用 iPhone 16 Pro 和小屏模拟器，各跑浅色、深色和至少一种大字体：

```bash
swiftlint --quiet
bash tools/ci-lint.sh
bash tools/visual-checks.sh
bash tools/capture-screenshots.sh --build
bash tools/run-visual-regression.sh
bash tools/run-ui-v4-regression.sh
bash scripts/scan-crash-logs.sh --json
```

重点检查：

- 首屏主动作、推送地址、应用管理、API 示例层级清晰，没有“大块空白 + 密集卡片”回归。
- 网关验证报告在小屏和大字体下无截断，按钮触控区域至少 44pt。
- 强离线安装/回滚状态不遮挡退出控制，不出现无限 spinner。
- Inbox/Markdown/审批详情仍与既有截图和协议一致。
- 所有颜色来自 `ThemeTokens.Color.*`，深色模式文本对比可读。
- 崩溃扫描必须为 `"total": 0`；若不为零，立即停止发布结论并定位。

## Task 5：公共服务与真实设备证据边界

运行：

```bash
bash tools/verify-shanbox-backend.sh
bash tools/verify-shanbox-supervision.sh
bash tools/verify-shanbox-fixtures.sh
```

这些只能证明路由、进程托管和公共 fixture 可达。不得据此声称真实 APNs、锁屏通知或后台行为通过。

若有付费 Apple Developer Program team 和配对 iPhone，再运行：

```bash
bash tools/run-real-device-smoke.sh
bash tools/verify-real-device-push-readiness.sh
```

若缺少 Push capability/profile 或设备，报告为 `MANUAL/UNAVAILABLE`，而不是伪造 PASS。真实设备至少人工观察：授权、token 登记、普通/Markdown/验证码通知到达、点击路由、锁屏/后台行为。

## Task 6：一键验收脚本与报告

新增 `verify-next-phase-acceptance.sh`，按成本从低到高执行：静态协议/单测 -> 服务端 -> iOS 模块 -> UI -> 崩溃扫描。脚本要求：

- 每项输出 PASS/FAIL/UNAVAILABLE 和证据路径。
- 任一强制项失败返回非零。
- 真实设备项没有环境时标记 MANUAL，不影响模拟器合同，但阻止“真实 APNs 可用”的发布声明。
- 不自动部署、不修改生产配置、不打印 secrets。

`next-phase-acceptance.md` 至少包含：

| 模块 | 场景 | 命令 | 结果 | 证据 | 限制 |
|---|---|---|---|---|---|
| 官方版 | 零配置首启 | ... | PASS/FAIL | ... | APNs 是否人工 |
| 自托管 | 导入/切换/删除 | ... | ... | ... | ... |
| 强离线 | 断网/回滚 | ... | ... | ... | ... |
| 消息 | 七类详情 | ... | ... | ... | ... |

更新模块可用性报告和发布清单后运行：

```bash
bash tools/verify-module-availability-report.sh
bash tools/run-release-gate.sh
```

## 发布验收标准

- [ ] 三个实现提交都基于同一 BASE_SHA，并可在 INTEGRATION_SHA 重现。
- [ ] 官方版无需配置网关/手工 Key，系统通知授权仍由用户明确触发。
- [ ] 自托管导入确认前零副作用，切换不继承旧权限。
- [ ] 强离线包经过双层 hash 校验、Application Support 持久化和失败回滚。
- [ ] 七类消息的列表、详情、默认打开和审批安全语义保持一致。
- [ ] AppTemplate 独立门禁通过，没有吸收产品 UI 或官方基础设施。
- [ ] lint、设计门禁、模块测试、UI 回归和 crash scan 全绿。
- [ ] 公共路由证据与真实 APNs/设备证据清楚分开。

## 缺陷回交规则

按所有权分派：

- 官方身份、首推、服务注册持久化 -> 模型 1。
- QR/paste、验证报告、激活事务、权限隔离 -> 模型 2。
- digest、安装、断网、原子回滚 -> 模型 3。
- 测试基础设施、报告错误 -> 模型 4 自修。

每个缺陷必须包含：标题、严重级别、INTEGRATION_SHA、最小复现、期望/实际、日志/截图、归属模型。修复回来后只挑选对应提交，再完整重跑相关矩阵和最终 crash scan。

## 提交和交接

建议提交信息：

```text
test(release): verify official gateway and offline journeys
```

最终交接格式：

```text
Branch:
Integration SHA:
Implementation commits verified:
QA commit(s):
Automated gates with exact pass/fail counts:
Screenshot/report paths:
Blocking defects:
Non-blocking debt:
Manual real-device checks:
Release recommendation: GO / NO-GO / GO-WITH-MANUAL-GATE
```
