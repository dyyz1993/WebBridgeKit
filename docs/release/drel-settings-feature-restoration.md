# Drel 设置功能暂缓与恢复手册

## 目的

本手册约束 Drel 首发版本中暂不展示的设置功能。目标是缩小首发产品面，**不是删除功能源码**。

每个暂缓功能必须保留在源代码、测试和 Git 历史中；发布版只通过编译条件排除入口、路由和页面。后续版本按本手册逐项恢复。

## 两类编译开关不得混用

| 开关 | 职责 | 恢复设置功能时能否修改 |
| --- | --- | --- |
| `DREL_CONTAINER_ONLY` | Drel Store 版的安全边界：远程网页没有原生 Bridge、消息处理器或能力授权页面。 | **不能。** 恢复收藏、历史或加密页不等于开放 Bridge。 |
| `DREL_RELEASE_MINIMAL_SETTINGS` | 首发版的临时设置导航白名单。仅控制哪些原生设置页面可见和可路由。 | 可以按版本、按功能调整。 |

`DREL_CONTAINER_ONLY` 同时存在于 `WebBridgeKit` 和 `SuperApp` 的 Release 配置；任何恢复工作都不得删掉或替换它。详见 [容器模式验证](../verification/drel-container-only-release.md)。

## 版本恢复台账（2026-09-13 更新）

| 版本 / train | 编译条件 | 设置页实际构成 | 2026-09-13 变更 |
| --- | --- | --- | --- |
| 1.0.1 App Store（`Release` 配置） | `DREL_CONTAINER_ONLY` + `DREL_RELEASE_MINIMAL_SETTINGS` | 白名单五项：通知设置、推送通道（自托管/官方）、存储管理、外观、关于 | 无新恢复；存储管理与推送通道页的修复对它同样生效（全 train 暴露项） |
| 1.4.0（`Drel14Release` 配置） | 仅 `DREL_CONTAINER_ONLY` | 白名单五项 + hero 推送密钥卡、收藏夹、最近访问、默认启动应用 | ① hero 推送密钥卡改为读取 `OfficialPushIdentityStore`（与推送通道页同源，满足“必须先改为 Drel 身份模型”的前置）；② 收藏夹恢复完成（生产入口补齐，见暂缓清单标注）；③ 密钥管理泄漏已收回（仅 Debug 可见）；④ 存储管理新增「存储构成」分解，全部清除覆盖 WKWebsiteDataStore；⑤ 推送通道页卡片化重写 |
| Debug 开发版 | 无旗标 | 全量（含调试组、口令管理、网页授权管理、推送加密） | 密钥管理仅此版本保留；首页收藏区标题 key 修正（`home.section.my_favorites`） |

验证信号（2026-09-13）：`bash tools/verify-drel-container-only.sh` **39 passed, 0 failed**；Drel14Release 模拟器逐页实机复验通过；审计报告与截图在 `build/audit-20260913/index.html`（gitignored）。

## 首发设置白名单

首发版应保留以下页面：

1. **通知设置**：跳转 iOS 的 Drel 通知设置。
2. **自托管推送**：扫码或粘贴用户自行部署的 HTTPS 推送服务；只完成 Drel
   设备配对与 APNs 加密投递，不导入网页工具或 Bridge 权限。
3. **存储管理**：查看和清理 Drel 的本地数据。
4. **外观**：跟随系统、浅色或深色显示。
5. **关于、支持与隐私**：说明首发能力、开源归属和公开联系入口。

## 暂缓功能清单

| 功能 | 首发处理 | 不删除的原因 | 恢复前置条件 |
| --- | --- | --- | --- |
| 旧“推送密钥 / 推送身份未配置”卡片 | 移除，改由首页的 Drel 个人推送地址承担该任务。 | 旧安装用户和兼容迁移仍可能需要读取历史数据。 | 不按原样恢复；必须先改为 Drel 身份模型，不能再提 Bark Key。 |
| 旧“密钥管理” | 编译排除。 | 包含本地临时密钥的历史实现，供兼容改造参考。 | 自托管兼容推送有完整协议、服务端授权和文档后，改名为“兼容推送配置（高级）”。 **（2026-09-13）**1.4.0 train 曾因 `DREL_RELEASE_MINIMAL_SETTINGS` 缺席而泄漏暴露该行；现已收紧为 `#if !DREL_CONTAINER_ONLY`（仅 Debug 完整版可见），恢复前维持编译排除状态。 |
| 通用网关配置 / 网页工具管理 | 编译排除。 | 自托管推送是独立的已允许入口；远程网页工具仍是后续体验。 | 完成独立版本计划、审核材料和真机验证后再恢复；不能与自托管推送配置混在同一设置页。 |
| 默认启动应用 | 编译排除。 | 依赖网页工具管理和本地软件包策略。 | 网页工具已经可由用户明确安装、移除和审计后再恢复。 |
| 收藏夹 | 编译排除。 | 已有本地收藏、置顶和删除实现。 | 用户可从容器内明确添加/移除工具，并有空状态与隐私说明。 **（2026-09-13）**1.4.0 train 已恢复入口，且生产入口已补齐：普通网页/推送链接浏览器（`WebViewController`）右上角星标收藏、manifest 浏览器 … 菜单「收藏页面/书签」文案中文化；死「+」按钮与 per-item 缓存模式开关移除；example.com/httpbin.org 降级出预置推荐。 |
| 最近访问 | 编译排除。 | 已有本地访问记录实现。 | 改名为“最近打开的工具”，并确认仅记录本地容器活动。 |
| 推送加密 | 编译排除。 | AES-GCM 解密链路仍是可选能力。 | 有公开的发送端格式、密钥轮换/丢失说明和端到端真机测试。 |
| 缓存仪表盘 | 编译排除；保留“存储管理”。 | 诊断统计仍适合 Debug。 | 仅在移除“后端服务/活跃系统”等开发措辞并转为用户存储页后恢复。 |

## 实施方式

不要删除 Swift 文件、Xcode target source、测试或数据模型。设置页收口时：

1. 在 `project.yml` 的 **SuperApp Release** 编译条件中保留
   `DREL_CONTAINER_ONLY`，并增加独立的
   `DREL_RELEASE_MINIMAL_SETTINGS`。
2. 在 `SettingsViewModel` 中，对每个暂缓 `SettingsItem` 使用
   `#if !DREL_RELEASE_MINIMAL_SETTINGS`。
   **例外**：`自托管推送` 是 Release 白名单的一部分，必须始终只路由到
   `SelfHostedPushConfigurationViewController`，不得复用 `GatewayConfigurationViewController`。
3. 在 `SettingsView.handleAction` 和
   `TabBarController.handleSettingsNavigation` 对同一目的地使用相同条件。
   不能只隐藏列表行，否则深链、状态恢复或未来入口仍可能打开页面。
4. 仅为 Debug 保留的诊断页继续使用 `#if DEBUG`；不得把它们改成普通
   Release 功能。
5. 若 `project.yml` 有改动，运行 `xcodegen generate && pod install` 后再构建。

## 恢复单个功能的操作手册

以“最近打开的工具”为例。其他暂缓项遵循相同顺序。

1. 写清本次版本要解决的用户任务、入口、空状态和数据保留规则；不要把“代码还在”当作上线理由。
2. 恢复该功能对应的 `SettingsItem`、`SettingsView` 路由和
   `TabBarController` 路由；不要触碰其他暂缓功能。
3. 改正名称、说明和辅助功能标签。例如“最近访问”应改为“最近打开的工具”。
4. 添加或更新该功能的 UI/模型测试，覆盖：入口可见、打开、空状态、核心操作、返回设置页。
5. 在模拟器构建 Release 并完成下面的发布门；真机仅用于 APNs、锁屏和 TestFlight 不能由模拟器证明的行为。
6. 新建递增 Build 上传 TestFlight，确认旧数据不会因升级丢失，再考虑 App Store 提交。

## 必过验证门

```bash
# 首先确保项目生成文件与 project.yml 同步
xcodegen generate && pod install

# 仍然必须保持 Store 容器安全边界
bash tools/verify-drel-container-only.sh

# 设置页/模块可用性回归（按当前测试 target 调整 destination）
xcodebuild test -workspace WebBridgeKit.xcworkspace -scheme SuperApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:SuperAppUITests/ModuleAvailabilityTests

# 最终 Release 门：包含 Debug 排除、容器策略与归档检查
bash tools/run-release-gate.sh
```

若恢复的是推送加密，还必须补做生产签名 TestFlight 的前台、后台和锁屏解密验证。若恢复的是任何 Bridge 相关能力，不能按本手册直接恢复：必须另开版本计划、App Review 说明和安全审查，且仍需先评估是否保留 `DREL_CONTAINER_ONLY`。

## 恢复前检查清单

- [ ] `DREL_CONTAINER_ONLY` 在两个 Release target 中仍存在。
- [ ] 未删除任何暂缓功能的源文件或测试。
- [ ] 列表入口、SwiftUI action 和 UIKit 路由条件一致。
- [ ] 页面文案不再出现 WebBridgeKit、Bark 或“后端服务已启动”等内部术语。
- [ ] 新 Build 的归档通过 `tools/run-release-gate.sh`。
- [ ] TestFlight 升级后，现有推送身份、网关和离线数据仍可用。

## 相关文档

- [Drel 容器模式发布验证](../verification/drel-container-only-release.md)
- [Drel 容器模式网页启动协议](../api/drel-container-only-launch.md)
- [首发 App Review 操作说明](app-review-walkthrough.md)
