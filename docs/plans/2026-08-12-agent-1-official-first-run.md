# Official First Run and Push Identity Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 让官方版用户安装后无需配置网关或手工创建推送 Key，即可在一次明确授权后复制推送地址、运行示例并收到第一条通知。

**Architecture:** 官方网关仍由 `HTMLAppGatewayDefaults.official` 内建；客户端在本机生成随机、不可预测的设备推送身份并安全持久化，APNs 授权成功后向官方服务登记。服务端用同一个可持久化注册表完成登记和按 Key 投递。系统通知权限必须由用户主动触发，配置免费不等于绕过系统授权。

**Tech Stack:** Swift/UIKit/SwiftUI, Security.framework Keychain, UserNotifications, Hummingbird 2, XCTest/XCUITest

---

## 任务身份

你是 WebBridgeKit 的“官方版零配置首启”开发者。只处理官方托管用户从首次打开到发送第一条通知的链路。不要处理自托管网关导入、强离线包、Inbox 视觉重做，也不要修改 AppTemplate。

## 启动前硬门槛

1. 先完整阅读根目录 `AGENTS.md`、`docs/plans/2026-08-12-home-redesign-figma-design.md`、`docs/plans/2026-08-12-official-selfhosted-onboarding-design.md`、`docs/api/message-types-v1.md`。
2. 由协调者填写 `BASE_SHA=<待填写>`。若未填写，停止并报告，不要猜测。
3. 在独立 worktree/分支 `codex/official-first-run` 工作；确认 `git rev-parse HEAD` 等于 `BASE_SHA`，且 `git status --short` 为空。
4. 开始前运行 `bash scripts/services.sh start` 和 `bash scripts/services.sh verify`。
5. iOS 构建和测试前阅读已安装的 XcodeBuildMCP skill；优先用 XcodeBuildMCP。若不可用，再使用 `AGENTS.md` 中的 `xcodebuild` 命令。

## 文件所有权

允许修改或新建：

- `Sources/Message/PushDeviceIdentity.swift`（新建）
- `Tests/MessageTests/PushDeviceIdentityTests.swift`（新建）
- `SuperApp/Sources/Services/OfficialPushIdentityStore.swift`（新建）
- `SuperApp/Sources/Push/PushNotificationManager.swift`
- `SuperApp/Sources/Controllers/Settings/PWAAppCenterViewController.swift`
- `SuperApp/Sources/Views/PWAHome/PWAHomeView.swift`
- `SuperApp/Sources/Views/PWAHome/PushExampleCatalogView.swift`
- `SuperApp/Resources/zh-Hans.lproj/Localizable.strings`
- `SuperApp/Resources/en.lproj/Localizable.strings`
- `SuperAppUITests/OfficialFirstRunTests.swift`（新建）
- `Server/Sources/WebBridgeServer/Configuration.swift`
- `Server/Sources/WebBridgeServer/Services/TokenStore.swift`
- `Server/Sources/WebBridgeServer/Services/APNsService.swift`（仅在注入共享注册表确有需要时）
- `Server/Tests/WebBridgeServerTests/TokenStoreTests.swift`（新建）
- `Server/Tests/WebBridgeServerTests/PushRoutesTests.swift`
- `docs/guides/official-quickstart.md`

共享本地化文件只新增 `official.push.*` 前缀键；不要重排或格式化其他键。模型 2 只使用 `gateway.*`，集成时若发生文本级冲突，仅合并两组新增键。

只读、禁止修改：

- `AppTemplate/**`
- `Sources/Runtime/**`
- `Sources/Models/HTMLAppRuntimeModels.swift`
- `SuperApp/Sources/Controllers/Settings/GatewayConfigurationViewController.swift`
- `Sources/Handlers/ManifestLoader/**`
- 其他模型拥有的测试、文档和工具脚本

若必须越界，先在交接报告提出，不要直接修改。

## 不可协商的产品和安全规则

- 官方版首次进入不能出现网关地址、服务端地址或 Key 配置表单。
- 官方网关自动可用，但通知权限不能在冷启动时突然弹出；仅在用户点“启用通知”或“发送第一条通知”时请求。
- 推送 Key 使用 32 字节安全随机数生成并编码为 URL-safe 字符串；不得使用设备名、UUID、时间戳或硬编码值。
- Key 存入 Keychain，建议 `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`；日志、错误、测试附件不得输出完整 Key 或 APNs token。
- 删除/重装后的新身份可以变化；同一安装内重启必须稳定。
- 推送地址在身份准备完成后可复制。身份未登记时必须明确显示“启用通知”，不能给出看似可用但必然失败的地址。
- 测试环境只能证明本地状态机和服务端路由，不能声称模拟器已完成真实 APNs 投递。
- 保留 Bark 风格 GET 和结构化 POST 兼容，不改变 `message-types-v1` 现有字段含义。

## Task 1：先用测试固定推送身份合同

新增一个不依赖 Keychain 的可测试核心类型：

```swift
public protocol PushDeviceIdentityStorage {
    func load() throws -> String?
    func save(_ value: String) throws
}

public struct PushDeviceIdentityProvider {
    public init(storage: PushDeviceIdentityStorage, randomBytes: @escaping (Int) throws -> Data)
    public func currentOrCreate() throws -> String
}
```

先写失败测试，再实现：

1. 空存储会生成 32 字节随机身份并保存。
2. 再次调用返回同一身份，不重新生成。
3. 输出只含 URL-safe 字符，不含 `/`、`+`、`=`。
4. 随机源或存储失败时显式抛错，不回退到弱随机值。

运行：

```bash
xcodebuild test -workspace WebBridgeKit.xcworkspace -scheme MessageTests \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:MessageTests/PushDeviceIdentityTests
```

预期：新增测试全部通过，业务代码无 warning。

## Task 2：让服务端登记跨重启持久化

先在 `TokenStoreTests` 写失败测试：

1. 注册后使用同一存储文件重建 `TokenStore`，仍可按 Key 找到设备。
2. 更新同一 token 不产生重复记录。
3. 损坏文件返回受控错误或隔离损坏文件，不能崩溃、不能静默覆盖成空数据。
4. 写入采用临时文件加原子替换；并发登记后 JSON 仍可解码。

实现要求：

- 从服务数据目录注入明确的注册文件路径，不写 `/tmp`、WebKit cache 或工程目录。
- `ServiceRegistry` 只创建一个 `TokenStore` 实例，并把同一实例交给 `APNsService`；删除冗余、不可观察的第二份状态源。
- 持久化内容不得包含 APNs 私钥或其他服务端秘密。
- 不改变 `/register` 和 Bark 兼容路由的外部请求结构。

运行：

```bash
(cd Server && swift test --filter TokenStoreTests)
(cd Server && swift test --filter PushRoutesTests)
```

预期：两个测试组 0 failure；服务重建测试证明登记仍存在。

## Task 3：实现官方版首启状态机

在 SuperApp 中增加 Keychain 适配器，并将界面收敛到以下状态：

```text
identityPreparing -> permissionRequired -> registering -> ready
                                      \-> denied
                         any state -----> recoverableError
```

行为要求：

- 首次打开静默创建本地身份、自动激活官方网关，不弹权限框。
- 用户点主按钮后查询当前通知权限；未决定时请求，已拒绝时提供“前往系统设置”，已授权时注册 APNs。
- 拿到 APNs token 后，以本地身份作为 Key 调用 `/register`；登记成功才进入 `ready`。
- `ready` 显示一条可复制的 Bark 风格推送地址、标题/正文输入和“在 Safari 测试”。
- 普通、Markdown、验证码、二维码、图片、聊天、审批示例仍由统一目录生成；不在每个按钮复制 URL 拼接逻辑。
- Safari 测试是外部真实请求路径；UI 测试可用仅测试构建下的 URL-open 记录器替代跨应用断言。
- 任何错误都给出具体恢复动作；不能让用户去“设置网关”。

辅助功能标识至少包括：

```text
home.push.enable
home.push.permission-denied
home.push.address
home.push.copy
home.push.send-safari
home.push.status
```

## Task 4：端到端测试官方首次使用

新增 `OfficialFirstRunTests.swift`，通过受控 launch argument/environment 注入假权限、假 APNs token 和本地登记服务。测试钩子必须只在 UI testing/DEBUG 生效。

至少覆盖：

1. 新安装进入首页不显示网关配置表单。
2. 未授权时主按钮文案是“启用通知”或同义明确动作。
3. 授权并完成假登记后出现可复制推送地址。
4. 复制地址包含当前身份，且不把身份写入测试日志。
5. 七类示例均可生成有效 URL；Markdown 和审批参数没有被降级成普通正文。
6. 权限拒绝时出现系统设置恢复入口。
7. 服务不可用时保留身份和输入内容，重试成功后恢复，不重新生成 Key。

不要把真实 APNs 收件写成自动化通过条件。

## Task 5：文档和完整验证

更新 `official-quickstart.md`，以大白话写成三步：安装并打开、点一次启用通知、复制地址或打开示例。说明系统授权是唯一必要交互；不要出现自托管部署步骤。

依次运行：

```bash
bash scripts/services.sh verify
(cd Server && swift test)
bash tools/verify-message-types-v1.sh
bash tools/verify-approval-v1.sh
bash tools/run-template-gate.sh
swiftlint --quiet
bash tools/ci-lint.sh
bash scripts/scan-crash-logs.sh --json
```

预期：相关测试全通过，lint 0 failure，崩溃扫描 `"total": 0`。`run-template-gate.sh` 必须证明 AppTemplate 未被产品功能污染。

## 验收标准

- [ ] 官方版首次进入没有网关设置门槛。
- [ ] 本地推送身份安全随机、Keychain 持久、日志脱敏。
- [ ] 未经用户操作不弹通知权限。
- [ ] 授权、APNs token、服务登记三者都完成后才声明地址可用。
- [ ] 服务重启后登记仍存在。
- [ ] 普通、Markdown、验证码、二维码、图片、聊天、审批示例均保留协议字段。
- [ ] 模拟器结果没有被描述成真实 APNs 送达证据。
- [ ] AppTemplate 和自托管网关文件零改动。

## 提交和交接

只提交本任务拥有的文件，建议提交信息：

```text
feat(official): make first push configuration-free
```

交接必须包含：

```text
Branch:
Base SHA:
Commit(s):
Changed files:
Tests and exact pass/fail counts:
Artifacts/screenshots:
Known limitations:
Integration notes/public API changes:
Real-device items still manual:
```
