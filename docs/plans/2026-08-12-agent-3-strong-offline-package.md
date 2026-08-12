# Strong Offline HTML App Package Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为签名 HTML App 增加真正可验证、可回滚、可长期保存的强离线包，使已安装 PWA 在断网和 WebKit cache 被清空后仍能从可信本地版本启动。

**Architecture:** 已签名的顶层 HTML App manifest 固定资源清单 URL 和其 SHA-256；资源清单再固定每个文件的路径、URL、大小与 SHA-256。下载进入 staging，逐文件校验后以目录替换原子激活；活动版本位于 Application Support，失败时保留旧版本。WebKit cache 只做性能优化，不作为可用性事实来源。

**Tech Stack:** Swift, CryptoKit, URLSession, FileManager, WKURLSchemeHandler/PersistentManifestLoader, XCTest, local HTTP fixtures

---

## 任务身份

你是 WebBridgeKit 的“强离线 HTML App 包”开发者。只处理离线包协议、校验、安装、回滚和启动。不要处理官方首启、自托管导入 UI、Inbox 或 AppTemplate。

## 启动前硬门槛

1. 先完整阅读根目录 `AGENTS.md`、`docs/architecture/html-app-runtime-protocol.md`、`docs/adr/0001-generic-html-app-runtime.md`、`Sources/Runtime/HTMLAppLaunchRuntime.swift`、`Sources/Handlers/ManifestLoader/` 全部相关文件。
2. 由协调者填写 `BASE_SHA=<待填写>`。未填写时停止并报告。
3. 在独立 worktree/分支 `codex/strong-offline-package` 工作；HEAD 必须等于 `BASE_SHA`，工作区必须干净。
4. 运行 `bash scripts/services.sh start`、`bash scripts/services.sh verify`。
5. iOS 构建和测试前完整阅读 XcodeBuildMCP skill；按 skill 和 `AGENTS.md` 使用正确的模拟器与本地端口。

## 文件所有权

允许修改或新建：

- `Sources/Models/HTMLAppRuntimeModels.swift`
- `Sources/Runtime/HTMLAppLaunchRuntime.swift`
- `Sources/Runtime/HTMLAppOfflinePackageModels.swift`（新建）
- `Sources/Runtime/HTMLAppOfflinePackageInstaller.swift`（新建）
- `Sources/Handlers/ManifestLoader/ManifestLoaderTypes.swift`
- `Sources/Handlers/ManifestLoader/ManifestDownloadService.swift`
- `Sources/Handlers/ManifestLoader/PersistentManifestLoader.swift`
- `Sources/Handlers/ManifestLoader/ManifestProgressUI.swift`（仅安装状态映射）
- `Tests/ModelsTests/HTMLAppRuntimeModelsTests.swift`
- `Tests/ModelsTests/HTMLAppLaunchRuntimeTests.swift`
- `Tests/CacheTests/HTMLAppOfflinePackageInstallerTests.swift`（新建）
- `Tests/CacheTests/PersistentManifestLoaderTests.swift`（存在则扩展，否则新建）
- `test_resources/offline-package/**`（新建确定性 fixture）
- `tools/verify-strong-offline-package.sh`（新建）
- `tools/run-cache-regression.sh`（只增加本任务门禁）
- `docs/api/offline-package-v1.md`（新建）
- `docs/architecture/strong-offline-packages.md`（新建）

禁止修改：

- `AppTemplate/**`
- `SuperApp/Sources/Views/PWAHome/**`
- `SuperApp/Sources/Controllers/Settings/**`
- `SuperApp/Sources/Push/**`
- `Sources/Runtime/HTMLAppGatewayConfiguration.swift`
- `Sources/Runtime/HTMLAppGatewayOnboarding.swift`
- `Sources/Runtime/HTMLAppRuntime.swift`
- `Server/**`
- 其他模型拥有的 UI tests、文档和工具

若模型 2 的 gateway canonical signing 需要自然包含新增可选字段，依赖 Codable 自动编码；不要越界改 onboarding 文件。无法集成时在交接中说明。

## 协议设计

在已签名顶层 manifest 的 `cache` 中增加向后兼容可选字段：

```json
{
  "strategy": "manifest",
  "version": "42",
  "persistent": true,
  "resourceManifestURL": "https://example.com/apps/demo/package.json",
  "resourceManifestSHA256": "64_LOWERCASE_HEX"
}
```

资源清单建议保持浅层：

```json
{
  "schemaVersion": "1",
  "appId": "com.example.demo",
  "version": "42",
  "entrypoint": "index.html",
  "files": [
    {
      "path": "index.html",
      "url": "https://example.com/apps/demo/index.html",
      "sha256": "...",
      "size": 1234,
      "mimeType": "text/html"
    }
  ]
}
```

顶层 manifest 的签名覆盖 `resourceManifestSHA256`，从而固定资源清单；资源清单固定所有文件。兼容规则：旧 manifest 没有 digest 时仍可按现有部分离线/缓存路径工作，但不得标记为 `strong`。

## 安全和持久化硬规则

- 强离线资格必须同时满足：顶层 manifest 已可信验证、`persistent=true`、资源清单 URL 存在、资源清单 digest 存在且合法。
- 资源清单和文件 URL 必须为顶层 app 允许的 HTTPS origin；DEBUG localhost fixture 例外。
- 拒绝绝对路径、`..`、空路径、重复路径、符号链接、目录覆盖、大小为负或超过配置上限。
- 下载前后检查总文件数、单文件大小和总包大小，防止资源耗尽。
- 每个文件先校验 size，再校验 SHA-256；清单本身也必须先校验 SHA-256。
- 安装目录位于 `Library/Application Support/WebBridgeKit/Packages/<stable-app-id>/`，标记不参与 iCloud backup；不能使用 `Library/Caches`、WebKit cache 或临时目录作为活动版本。
- staging 使用随机目录；全部成功后原子切换 `current` 指针/目录。新版本失败时旧版本继续可启动。
- 强离线已有活动包时，启动不能因网络不可达而降级为空白页；在线更新失败应使用旧包并显示非阻塞状态。
- push 只能导航到 PWA，不得借由离线 HTML 自动批准敏感操作。

## Task 1：用模型测试固定强离线资格

在 `HTMLAppRuntimeModelsTests` 和 `HTMLAppLaunchRuntimeTests` 先写失败测试：

1. `persistent + URL + digest` 才解析为 strong offline eligible。
2. 旧 manifest 无 digest 保持可解码，但离线级别只能为 partial。
3. 非 64 位小写 hex digest、非 HTTPS 生产 URL、version/appId 不匹配失败。
4. Codable 往返保留 digest，顶层 canonical payload 因该字段变化而变化。
5. resolver 在已安装 strong 包存在时优先给出本地启动 target；无包时给出安装/联网状态，不伪装已可离线。

建议增加清晰计算属性：

```swift
public var isStrongOfflineEligible: Bool { ... }
```

不要把 `persistent == true` 直接等同于强离线。

## Task 2：先测试资源清单防御性解析

新增 `HTMLAppOfflinePackageInstallerTests`，使用内存 transport 和临时 Application Support 根目录，覆盖：

1. 合法包安装成功，活动版本和入口正确。
2. 清单 hash 不符时一个文件都不激活。
3. 任一文件 hash/size 不符时完整回滚。
4. `../escape`、绝对路径、重复路径、异源 URL、重定向异源、超限包失败。
5. 中途中断、磁盘写失败和并发安装不会损坏当前版本。
6. 新版安装成功后旧版可清理，但当前版本永远存在一个完整目录。
7. appId/version 与已签名父 manifest 不一致时失败。

为网络和文件系统建立可注入协议，不在测试中请求公网。

## Task 3：实现原子安装器

建议核心接口：

```swift
public protocol HTMLAppPackageTransport {
    func data(from url: URL, maximumBytes: Int) async throws -> Data
}

public actor HTMLAppOfflinePackageInstaller {
    public func install(
        appManifest: HTMLAppManifest,
        progress: @Sendable (HTMLAppPackageProgress) -> Void
    ) async throws -> InstalledHTMLAppPackage

    public func installedPackage(appId: String) async throws -> InstalledHTMLAppPackage?
}
```

实现顺序：

1. 校验父 manifest 的强离线资格。
2. 下载资源清单到内存上限内，比较父 manifest 固定的 SHA-256。
3. 解码并校验 schema/appId/version/path/origin/配额。
4. 建立 staging，逐文件下载到 staging 内部并校验。
5. 写入本地安装元数据，记录 manifest digest、文件 digest、安装时间和 entrypoint。
6. 原子切换活动目录；失败只删除 staging。
7. 对活动目录设置 file protection 和 exclude-from-backup；错误需可观察，不能 `try!`。

## Task 4：接入现有 Manifest Loader 和启动解析

重用现有自定义 scheme/loader，不另建第二套 WebView 资源协议：

- `PersistentManifestLoader` 在线安装时调用新安装器。
- 活动包存在时从 Application Support 读取并通过已有 scheme 返回正确 MIME type。
- 网络更新和本地启动分开：启动不等待更新；更新完成后下次启动切换新版本。
- 页面状态恢复数据与应用包分目录管理，更新包不能清除用户页面状态。
- 旧的 partial cache 路径保持可用，UI/模型清楚标记“部分离线”，不能冒充强离线。
- `ManifestProgressUI` 仅映射下载、校验、安装、使用旧版本等状态；不引入硬编码颜色。

## Task 5：确定性本地 fixture 和断网回归

在 `test_resources/offline-package/` 创建小型 HTML App：入口、CSS、JS、图片和 package manifest，hash 由脚本固定验证。增加两个破损 fixture：清单 hash 错和单文件 hash 错。

新增 `verify-strong-offline-package.sh`，至少验证：

1. fixture 资源清单与所有文件 hash 一致。
2. 包含 entrypoint 且路径安全。
3. 破损 fixture 的确被检测为错误，避免测试样本失效。
4. 安装后停止本地 `:8081` 时，单元/集成测试仍从活动包读取入口和静态资源。
5. 更新失败后活动版本号仍为旧版本。

脚本不得依赖公网。

## Task 6：文档和完整验证

`offline-package-v1.md` 写清发布者如何生成清单/digest、版本不可变性、配额、错误码和迁移规则。`strong-offline-packages.md` 写清信任链、目录布局、原子切换和清理策略。

运行：

```bash
bash scripts/services.sh verify
bash tools/verify-strong-offline-package.sh
bash tools/validate-cache-html.sh
bash tools/run-cache-regression.sh
bash tools/run-template-gate.sh
swiftlint --quiet
bash tools/ci-lint.sh
bash scripts/scan-crash-logs.sh --json
```

如使用 `xcodebuild`，至少运行新增 CacheTests、`HTMLAppRuntimeModelsTests` 和 `HTMLAppLaunchRuntimeTests`；报告精确测试数。

## 验收标准

- [ ] 信任链为“已签名父 manifest -> 资源清单 hash -> 每文件 hash”。
- [ ] 旧 manifest 可兼容，但不被误标强离线。
- [ ] 活动包位于 Application Support，不依赖 WebKit/Library Caches。
- [ ] 任一步失败都保留上一完整版本。
- [ ] 断网与清空 WebKit cache 后仍可打开已安装入口、CSS、JS 和图片。
- [ ] 路径穿越、异源、重定向、超限和 hash 错误全部有测试。
- [ ] AppTemplate、网关导入 UI、官方推送文件零改动。
- [ ] 不以 push 参数直接执行审批或其他敏感动作。

## 提交和交接

只提交本任务拥有的文件，建议提交信息：

```text
feat(offline): install signed atomic HTML app packages
```

交接格式：

```text
Branch:
Base SHA:
Commit(s):
Changed files:
Schema/public API changes:
Tests and exact pass/fail counts:
Fixture and report paths:
Disk/network failure cases proven:
Known limitations:
Integration notes:
```
