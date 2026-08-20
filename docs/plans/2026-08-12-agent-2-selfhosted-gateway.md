# Self-Hosted Gateway Import Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 把开源自托管版的网关接入收敛为一次 QR 或粘贴导入、完整本地验证、原生确认、显式激活的安全流程，并保证切换网关不会继承旧应用信任和权限。

**Architecture:** 可移植网关文档只描述公开端点和生产 Ed25519 公钥；解析、网络验证、签名校验与激活分层。所有验证先在内存中完成，确认前不写入；激活以事务方式替换网关、应用 manifest 和权限边界。官方默认路径保持无配置，本任务只增强自托管入口。

**Tech Stack:** Swift/UIKit/SwiftUI, AVFoundation QR scanning, URLSession, CryptoKit/Swift Crypto, XCTest/XCUITest

---

## 任务身份

你是 WebBridgeKit 的“开源自托管网关接入”开发者。只处理网关导入、验证、确认、切换和删除。不要改官方推送身份、强离线包、Inbox 或 AppTemplate。

## 启动前硬门槛

1. 先完整阅读根目录 `AGENTS.md`、`docs/plans/2026-08-12-official-selfhosted-onboarding-design.md`、`docs/guides/self-hosted-gateway-import.md`。
2. 由协调者填写 `BASE_SHA=<待填写>`。若未填写，停止并报告。
3. 在独立 worktree/分支 `codex/selfhosted-gateway` 工作；确认 HEAD 等于 `BASE_SHA` 且工作区干净。
4. 先运行 `bash scripts/services.sh start`、`bash scripts/services.sh verify`。
5. iOS 构建和测试前完整阅读已安装的 XcodeBuildMCP skill，并按其要求执行。

## 文件所有权

允许修改或新建：

- `Sources/Runtime/HTMLAppGatewayConfiguration.swift`
- `Sources/Runtime/HTMLAppGatewayOnboarding.swift`
- `Sources/Runtime/HTMLAppRuntime.swift`（只允许增加原子替换/回滚所需接口）
- `Tests/ModelsTests/HTMLAppGatewayConfigurationTests.swift`
- `Tests/ModelsTests/HTMLAppGatewayOnboardingTests.swift`
- `Tests/ModelsTests/HTMLAppRuntimeTests.swift`（仅事务行为）
- `SuperApp/Sources/Controllers/Settings/GatewayConfigurationViewController.swift`
- `SuperApp/Sources/Views/Gateway/GatewayImportView.swift`（新建）
- `SuperApp/Sources/Views/Gateway/GatewayValidationReportView.swift`（新建）
- `SuperApp/Sources/Views/Gateway/GatewayManagementViewModel.swift`（新建）
- `SuperApp/Resources/zh-Hans.lproj/Localizable.strings`
- `SuperApp/Resources/en.lproj/Localizable.strings`
- `SuperAppUITests/GatewayOnboardingTests.swift`（新建）
- `docs/api/gateway-v1.md`（新建）
- `docs/guides/self-hosted-gateway-import.md`

共享本地化文件只新增 `gateway.*` 前缀键；不要重排或格式化其他键。模型 1 只使用 `official.push.*`，集成时若发生文本级冲突，仅合并两组新增键。

禁止修改：

- `AppTemplate/**`
- `SuperApp/Sources/Views/PWAHome/**`
- `SuperApp/Sources/Controllers/Settings/PWAAppCenterViewController.swift`
- `SuperApp/Sources/Push/**`
- `Sources/Models/HTMLAppRuntimeModels.swift`
- `Sources/Handlers/ManifestLoader/**`
- `Server/**`
- 其他模型拥有的测试、工具和验证报告

现有 App Center 已提供网关管理入口；不要为了接线去改其文件。若基线入口缺失，作为集成问题报告。

## 固定协议

支持两种输入：

1. JSON 文档。
2. `webbridgekit://gateway?...` URL。

规范字段保持浅层，示例：

```json
{
  "schemaVersion": "1",
  "displayName": "My Gateway",
  "baseURL": "https://example.com",
  "healthEndpoint": "/health",
  "manifestEndpoint": "/manifest",
  "publicKeyId": "prod-2026-01",
  "publicKey": "BASE64_ED25519_PUBLIC_KEY"
}
```

不可协商规则：

- QR 中不得出现 APNs device token、API secret、私钥、管理 token 或用户凭证。
- 生产环境只接受 exact-origin HTTPS；HTTP 仅允许 DEBUG 下的 loopback/localhost 开发端点。
- `healthEndpoint`、`manifestEndpoint` 必须与 `baseURL` 同源；拒绝用户名密码、fragment、路径穿越和重定向到异源。
- JSON 未知普通字段可以按版本策略处理，但任何疑似秘密字段（如 `privateKey`、`apiSecret`、`token`、`password`）必须拒绝并给出安全错误，不能因 `Decodable` 忽略未知键而放行。
- 所有 manifest 和签名验证通过后才允许显示“启用”。用户确认前不得写入或激活。
- 切换到新 origin 后，旧应用 manifest、能力授权和会话信任不能带过去。

## Task 1：先补齐恶意和边界输入测试

在 `HTMLAppGatewayConfigurationTests` 先写失败测试：

1. 合法 JSON 和 scheme URL 得到同一配置。
2. 缺少任一必填字段失败，并定位字段名。
3. 生产 HTTP、非 exact origin、异源 endpoint、带 credentials URL、fragment、路径穿越失败。
4. URL 重复关键 query 项失败，不采用“最后一个覆盖前一个”。
5. 输入含 `privateKey`、`apiSecret`、`token`、`password` 等秘密字段失败。
6. DEBUG 本地 HTTP 只允许 localhost、127.0.0.1 或明确 loopback；release 校验策略拒绝。
7. 公钥 Base64 长度或 Ed25519 格式不正确时失败。

实现解析器时先对原始 JSON/query 做键集合和秘密字段检查，再进入 Codable；错误类型应可本地化展示。

## Task 2：验证报告与确认前零副作用

在 `HTMLAppGatewayOnboardingTests` 先覆盖：

1. 健康检查失败、超时、非 JSON 或 schema 不匹配时不写入。
2. manifest 列表任一项目 appId、origin、签名或公钥 ID 不合法时整批失败。
3. 验证成功只返回 `GatewayValidationReport`，此时 registry、manifest、权限均未变化。
4. 报告至少包含 display name、host、health endpoint、manifest endpoint、公钥 ID、应用数和逐项结果。
5. 服务器重定向到异源时失败。

建议将流程明确拆成：

```swift
parse(input) -> GatewayCandidate
validate(candidate) async -> GatewayValidationReport
activate(report) async throws
```

不要让 `validate` 内部调用 `activate`。

## Task 3：实现事务式激活、切换和删除

先写事务失败测试：在保存第 N 个 manifest 或持久化网关失败时，当前激活网关、旧 manifest 和旧权限全部保持原状。

实现要求：

- 激活前保存旧状态快照，或提供单一 `replaceGatewayBundle` 原子接口；禁止逐项永久写入后无回滚。
- 同一网关更新可以保留仅属于同一稳定 app identity 且仍合法的非敏感设置；跨 origin 或公钥身份变化默认清除授权。
- 删除活动网关需二次确认，删除后清理该网关下的 manifest 和 permission grants。
- 官方默认网关不能因用户导入失败而被破坏。
- 错误信息要区分：解析失败、网络不可达、TLS/同源失败、签名失败、保存失败。

## Task 4：原生、少嵌套的导入界面

将现有多层 alert 流程重构为一条清晰路径：

```text
网关管理 -> 扫码或粘贴 -> 验证中 -> 原生验证报告 -> 启用完成
```

界面要求：

- 首页只显示当前网关、状态、切换/删除、扫码、粘贴，不塞入协议说明全文。
- 扫码和粘贴进入同一解析/验证管线。
- 确认页明确显示 host、两个 endpoint、公钥 ID、发现的应用数和失败项；按钮为“启用此网关”。
- 验证失败留在当前上下文，可修改/重试，不自动退回根页。
- 扫码相机权限拒绝时提供粘贴入口和系统设置入口。
- 支持 Dynamic Type、VoiceOver、深色模式和小屏；不硬编码颜色，全部使用 `ThemeTokens.Color.*`。

辅助功能标识至少包括：

```text
gateway.current
gateway.scan
gateway.paste
gateway.input
gateway.validate
gateway.report
gateway.activate
gateway.remove
gateway.error
```

## Task 5：UI 与协议验证

新增 `GatewayOnboardingTests.swift`，覆盖：

1. 粘贴合法 payload 后先出现报告，未点启用前当前网关不变。
2. 报告展示 host、endpoint、公钥 ID、应用数。
3. 用户确认后新网关成为活动项。
4. 恶意 secret 字段、生产 HTTP、签名错误出现具体错误且不激活。
5. 切换 origin 后旧授权不会出现在新应用下。
6. 删除活动自托管网关后清理状态并返回安全默认状态。
7. 扫码按钮存在；相同 QR 字符串的解析由单元测试证明，不要求自动化操纵相机。

更新 `gateway-v1.md`：包含 schema、字段约束、合法/非法例子、签名关系、HTTP 错误语义和部署者生成 QR 的命令示例。文档不得示范携带私密值。

## Task 6：完整验证

```bash
xcodebuild test -workspace WebBridgeKit.xcworkspace -scheme ModelsTests \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:ModelsTests/HTMLAppGatewayConfigurationTests \
  -only-testing:ModelsTests/HTMLAppGatewayOnboardingTests \
  -only-testing:ModelsTests/HTMLAppRuntimeTests

WBK_GATEWAY_URL=https://cloak.xbrowser.dev:5801 bash tools/verify-open-gateway.sh
bash tools/run-template-gate.sh
swiftlint --quiet
bash tools/ci-lint.sh
bash scripts/scan-crash-logs.sh --json
```

公共网关验证预期为 `5 passed, 0 failed`；它只证明 HTTPS 网关合同和可达性，不证明 APNs。

## 验收标准

- [ ] JSON 与 scheme URL 共用同一解析器和验证规则。
- [ ] QR/paste 不允许秘密或私钥。
- [ ] production exact-origin HTTPS、Ed25519 签名和 manifest 全量验证生效。
- [ ] 确认前零持久化副作用。
- [ ] 激活失败完整回滚，不出现半个网关或半套 manifest。
- [ ] 切换和删除不会跨应用继承能力授权。
- [ ] 官方默认路径没有新增配置步骤。
- [ ] AppTemplate、官方推送和强离线文件零改动。

## 提交和交接

只提交本任务拥有的文件，建议提交信息：

```text
feat(gateway): harden one-time self-hosted onboarding
```

交接格式：

```text
Branch:
Base SHA:
Commit(s):
Changed files:
Tests and exact pass/fail counts:
Public gateway verification result:
Screenshots/artifacts:
Known limitations:
Integration notes/public API changes:
```
