# WebBridgeKit 架构升级实施计划

## 总览

将项目从当前状态升级为四层架构 + 基础设施层 + AI 接口。

**目标架构：**
```
SuperApp（业务）
    ↓
AppTemplate（脚手架：模板 + 示例 + 主题 + Debug Panel）
    ↓
Bridge 引擎 + Cache 引擎（独立模块）
    ↓
Infrastructure（日志 + 调试 + 诊断 + AI 接口）
```

**预计总工期：** 6 个阶段，每阶段 1-2 周

---

## Phase 1: Infrastructure 基础设施 — 日志 + 诊断

**目标：** 建立所有模块共用的日志和诊断基础设施

**优先级：** 🔴 最高（其他所有模块都依赖它）

### 任务清单

#### 1.1 结构化日志系统
- [ ] 创建 `Sources/Infrastructure/Logging/` 目录
- [ ] 实现 `StructuredLogger.swift`
  - JSON 格式日志输出
  - 支持分类：bridge / cache / network / handler / perf / error / lifecycle
  - 支持级别：debug / info / warning / error
  - 每条日志包含：timestamp / level / category / module / message / context
- [ ] 实现 `LogPipeline.swift`
  - Console 输出（Xcode 控制台，带颜色）
  - Memory 环形缓冲（保留最近 1000 条，可查询）
  - File 输出（自动轮转，最大 10MB）
  - 自定义回调注册
- [ ] 实现 `LogQuery.swift`
  - 按分类查询：`logs(category: .bridge)`
  - 按级别过滤：`logs(minLevel: .error)`
  - 按时间范围：`logs(from: date, to: date)`
  - 按关键词搜索：`logs(search: "camera")`
  - 导出为 JSON/文本格式
- [ ] 替换现有 `WebBridgeLogger.swift` 为新系统
  - 保持向后兼容的包装器
- [ ] 测试：`Tests/Infrastructure/LoggingTests.swift`

#### 1.2 诊断系统
- [ ] 创建 `Sources/Infrastructure/Diagnostic/` 目录
- [ ] 实现 `DiagnosticEngine.swift`
  - `checkAll()` 一键全检
  - `checkBridge()` Bridge 引擎状态
  - `checkCache()` 缓存系统状态
  - `checkNetwork()` 网络连通性
  - `checkStorage()` 存储空间
  - `checkPermissions()` 所有权限状态
- [ ] 实现 `ErrorContext.swift`
  - 错误发生时自动捕获上下文
  - 最近 20 条相关日志
  - Handler 名称 + 参数
  - WebView URL
  - 设备/网络/内存快照
  - 生成可复制的诊断报告（Markdown 格式）
- [ ] 实现 `EnvironmentInfo.swift`
  - App 版本 / Build 号
  - 设备型号 / iOS 版本 / 屏幕尺寸
  - 内存 / 存储空间
  - 网络类型 / VPN
  - 所有权限状态
  - `copyAll()` 一键复制
- [ ] 测试：`Tests/Infrastructure/DiagnosticTests.swift`

#### 1.3 验收标准
- [ ] 所有日志输出为结构化 JSON
- [ ] 日志可按分类/级别/时间查询
- [ ] 错误发生时自动生成诊断报告
- [ ] 环境信息可一键复制
- [ ] 不影响现有功能（向后兼容）

---

## Phase 2: Bridge 框架重构 — Handler 协议 + 注册发现

**目标：** 统一 Handler 协议，支持元数据声明和自动发现

**优先级：** 🔴 最高（Debug Panel 和 AI 接口依赖它）

### 任务清单

#### 2.1 Handler 协议升级
- [ ] 设计 `HandlerMeta` 元数据结构
  ```swift
  struct HandlerMeta {
      let action: String              // "camera"
      let category: HandlerCategory   // .hardware
      let displayName: String         // "相机"
      let description: String         // "调用设备摄像头拍照或录像"
      let requiredPermissions: [PermissionType]
      let parameters: [ParamDef]      // 参数定义（自动生成表单）
      let returns: [ReturnDef]        // 返回值定义
      let version: String             // Handler 版本
      let supportedPlatforms: [Platform]  // 支持的平台
  }
  
  enum HandlerCategory: String, CaseIterable {
      case hardware, media, navigation, system, feedback
      case sensor, clipboard, permission, debug, cache
  }
  
  struct ParamDef {
      let name: String
      let type: ParamType              // .string / .int / .bool / .enum / .array
      let required: Bool
      let defaultValue: Any?
      let description: String
      let options: [String]?           // 枚举值
  }
  ```
- [ ] 扩展 `WebNativeAPI` 协议
  ```swift
  protocol WebNativeAPI {
      static var meta: HandlerMeta { get }
      func handle(params: [String: Any], callback: @escaping (WebBridgeResponse) -> Void)
  }
  ```
- [ ] 为所有 35 个 Handler 补充 meta 声明

#### 2.2 注册发现机制
- [ ] 实现 `HandlerRegistry.swift`
  - 自动扫描所有注册的 Handler
  - `allHandlers()` → 返回所有 meta 列表
  - `handlers(category:)` → 按分类查询
  - `handler(action:)` → 按 action 查询
  - `handlerDescriptions()` → 生成 API 文档（JSON/Markdown）
- [ ] 改造 `WebJavaScriptBridge.swift`
  - 使用 HandlerRegistry 替代手动工厂字典
  - 保持懒加载机制

#### 2.3 统一异常处理
- [ ] 实现 `BridgeError.swift`（替换现有的 `WebBridgeError`）
  ```swift
  enum BridgeError: Error, CustomStringConvertible {
      case permissionDenied(action: String, permission: String)
      case parameterInvalid(action: String, param: String, reason: String)
      case hardwareUnavailable(action: String, reason: String)
      case timeout(action: String, seconds: Double)
      case cancelled(action: String)
      case notSupported(action: String, reason: String)
      case executionFailed(action: String, error: Error)
      
      var description: String { ... }
      var debugInfo: String { ... }  // 可复制的完整调试信息
      var errorCode: String { ... }  // 标准错误码
  }
  ```
- [ ] 实现统一的错误响应格式
  ```json
  {
    "success": false,
    "error": {
      "code": "PERMISSION_DENIED",
      "action": "camera",
      "message": "Camera permission denied",
      "suggestion": "Please go to Settings > Privacy > Camera",
      "debugInfo": "..."
    }
  }
  ```
- [ ] 为每个 Handler 统一错误处理模式

#### 2.4 验收标准
- [ ] 所有 35 个 Handler 都有 meta 声明
- [ ] HandlerRegistry 可以查询所有 Handler 信息
- [ ] 所有错误遵循 BridgeError 统一格式
- [ ] 错误信息包含可复制的调试信息
- [ ] 现有 JS 调用完全兼容（不破坏 Web 端）

---

## Phase 3: Debug 调试系统

**目标：** 自动发现所有 Handler，提供可交互的调试面板

**优先级：** 🟠 高

### 任务清单

#### 3.1 Handler 自动发现引擎
- [ ] 实现 `HandlerDiscoveryEngine.swift`
  - 读取 HandlerRegistry 中的所有 meta
  - 按分类自动分组
  - 生成参数输入表单描述
  - 缓存发现结果

#### 3.2 Debug Panel UI
- [ ] 创建 `AppTemplate/Sources/Debug/` 目录
- [ ] 实现 `DebugPanelViewController.swift`
  - Tab 1: Handler 列表（按分类分组）
    - 每个 Handler 显示：名称 / 描述 / 分类标签
    - 点击进入 Handler 测试页
  - Tab 2: 日志查看器
    - 实时显示结构化日志
    - 按分类过滤
    - 搜索关键词
    - 点击复制任意一条
  - Tab 3: 缓存状态
    - 缓存列表 / 大小 / 命中率
  - Tab 4: 环境信息
    - 设备/网络/权限
    - 一键复制全部
- [ ] 实现 `HandlerTestViewController.swift`
  - 从 meta 自动生成参数输入表单
  - "执行" 按钮
  - 结果展示（JSON 格式化）
  - 一键复制结果
  - 错误展示 + 一键复制
  - 执行历史

#### 3.3 Debug Panel 触发方式
- [ ] 摇一摇触发
- [ ] 长按 Logo 3 秒
- [ ] URL Scheme: `app://debug`
- [ ] Debug 菜单入口（可配置显示/隐藏）
- [ ] 编译配置：`#if DEBUG` 自动启用

#### 3.4 Debug Panel 集成到脚手架
- [ ] AppTemplate 默认包含 Debug Panel
- [ ] 可通过配置关闭：`WebBridgeKitConfig.enableDebugPanel = false`
- [ ] SuperApp 也集成 Debug Panel

#### 3.5 验收标准
- [ ] Debug Panel 自动列出所有 35 个 Handler
- [ ] 每个 Handler 可以直接测试（填参数 → 执行 → 看结果）
- [ ] 新增 Handler 后 Debug Panel 自动出现，零维护
- [ ] 日志可以实时查看和搜索
- [ ] 所有结果/错误都可以一键复制
- [ ] Release 模式下 Debug Panel 自动隐藏

---

## Phase 4: Cache 独立化

**目标：** Cache 引擎完全独立，有完整接口和独立测试

**优先级：** 🟠 高

### 任务清单

#### 4.1 Cache 接口层定义
- [ ] 定义 Cache 公共协议
  ```swift
  protocol ManifestCacheManaging {
      func cacheManifest(url: URL, completion: @escaping (Result<CacheResult, Error>) -> Void)
      func hasCachedManifest(appID: String) -> Bool
      func loadCachedPage(appID: String, params: [String: Any]?) -> WebViewLoadResult
      func removeCache(appID: String)
      func clearAll()
      func getCacheStats() -> CacheStats
  }
  
  protocol ResourceCacheManaging {
      func storeResource(appID: String, path: String, data: Data, mimeType: String) throws
      func getResource(appID: String, path: String) -> (data: Data, mimeType: String)?
      func removeResource(appID: String, path: String)
      func getResourceCount(appID: String) -> Int
  }
  ```
- [ ] 隔离 Cache 模块的所有内部实现细节
- [ ] 确保 Cache 不依赖 Bridge（反向不依赖）

#### 4.2 Cache 独立测试套件
- [ ] ManifestCache 核心测试
  - manifest 下载和解析
  - 资源下载和缓存
  - 自定义 URL Scheme 拦截
  - 版本更新和缓存刷新
  - 离线加载验证
- [ ] ResourceCache 测试
  - 存储和读取
  - LRU 淘汰策略
  - 压缩存储
  - 并发安全
- [ ] CacheRule 测试
  - URL 匹配（精确/通配符/正则）
  - 规则优先级
  - 动态规则更新
- [ ] 极端场景测试
  - 磁盘空间不足
  - 网络中断
  - 损坏的 manifest
  - 超大文件

#### 4.3 Cache 调试接口
- [ ] 暴露 Cache 统计信息（命中率、大小、数量）
- [ ] 暴露 Cache 内容查询接口
- [ ] Debug Panel 中添加 Cache Tab

#### 4.4 验收标准
- [ ] Cache 模块零依赖 Bridge 代码
- [ ] 有独立的测试套件（覆盖率 > 80%）
- [ ] 所有公共接口通过协议暴露
- [ ] 可以在不使用 Bridge 的场景下独立使用 Cache

---

## Phase 5: AI Interface 接口层

**目标：** 暴露 HTTP API，让 AI 工具可以远程调试

**优先级：** 🟡 中

### 任务清单

#### 5.1 本地 HTTP Server
- [ ] 实现 `DebugHTTPServer.swift`（基于 `Swifter` 或 ` URLSession`）
  - 端口 8765（可配置）
  - 仅 DEBUG 模式启动
  - 仅监听 localhost（安全）
- [ ] 实现 API 路由
  - `GET /api/status` → App 运行状态
  - `GET /api/handlers` → 所有 Handler 列表 + meta
  - `GET /api/handlers/:action` → 单个 Handler 详情
  - `POST /api/handlers/:action/execute` → 远程执行 Handler
  - `GET /api/logs?category=&level=&limit=&search=` → 查询日志
  - `GET /api/cache/stats` → 缓存统计
  - `GET /api/cache/entries` → 缓存条目列表
  - `DELETE /api/cache/:appID` → 删除指定缓存
  - `GET /api/diagnostic` → 完整诊断报告
  - `GET /api/errors?limit=` → 最近错误列表
  - `GET /api/environment` → 环境信息
- [ ] 实现 WebSocket `/ws/events`
  - 实时推送 Bridge 调用事件
  - 实时推送日志
  - 实时推送错误

#### 5.2 接口安全
- [ ] 仅 DEBUG 编译配置下启用
- [ ] 仅监听 127.0.0.1
- [ ] 可通过配置关闭
- [ ] Rate limiting（防止滥用）

#### 5.3 MCP 协议适配
- [ ] 实现 MCP Tool 定义
  ```json
  {
    "name": "webbridgekit_debug",
    "description": "Debug WebBridgeKit-based iOS apps",
    "tools": [
      {
        "name": "get_status",
        "description": "Get app running status"
      },
      {
        "name": "list_handlers",
        "description": "List all registered native handlers"
      },
      {
        "name": "execute_handler",
        "description": "Execute a handler with parameters",
        "parameters": {
          "action": { "type": "string" },
          "params": { "type": "object" }
        }
      },
      {
        "name": "query_logs",
        "description": "Query structured logs"
      },
      {
        "name": "get_diagnostic",
        "description": "Get full diagnostic report"
      }
    ]
  }
  ```

#### 5.4 验收标准
- [ ] DEBUG 模式下 App 启动后自动开启 HTTP Server
- [ ] 所有 API 返回结构化 JSON
- [ ] AI 工具可以通过 HTTP 接口查询 App 状态
- [ ] AI 工具可以远程执行 Handler 测试
- [ ] 日志可以通过 API 实时查询
- [ ] WebSocket 实时推送事件
- [ ] Release 模式下完全不存在

---

## Phase 6: 脚手架升级 + 主题 + Skill

**目标：** 完善脚手架，沉淀 AI Skill

**优先级：** 🟡 中

### 任务清单

#### 6.1 AppTemplate 升级
- [ ] 添加主题系统
  - `AppTemplate/Sources/Theme/`
  - `AppTheme.swift` — 颜色/字体/间距/圆角
  - `ThemeColor.swift` — 主色/辅色/背景/文字/分割线
  - `ThemeTypography.swift` — 标题/正文/说明/代码
  - `ThemeSpacing.swift` — 间距规范
  - 支持 Light/Dark 模式
  - 可被上层覆盖
- [ ] 添加 Debug Panel（集成 Phase 3）
- [ ] 添加 AI Interface（集成 Phase 5）
- [ ] 添加使用示例
  - 每个 Handler 一个示例页面
  - 从 meta 自动生成（减少维护）
  - 可导航的示例列表

#### 6.2 SuperApp UI 重构
- [ ] 套用脚手架主题
- [ ] 重构首页桌面 UI
- [ ] 统一所有页面的视觉风格

#### 6.3 Skill 沉淀
- [ ] 创建 `.opencode/rules/webbridgekit-debug.mdc`
  - AI 工具调试 WebBridgeKit 项目的规范
- [ ] 创建 MCP Tool 定义文件
  - 让 AI 工具知道怎么调用 HTTP API
- [ ] 创建调试场景 Skill
  - 场景1: Handler 不工作 → 自动查日志 → 定位问题
  - 场景2: 缓存失效 → 自动查统计 → 找原因
  - 场景3: 页面白屏 → 自动查错误 → 诊断
- [ ] 验证：用 AI 工具 + Skill 调试脚手架项目

#### 6.4 文档
- [ ] 更新 README.md
- [ ] 架构说明文档
- [ ] Handler 开发指南
- [ ] 脚手架使用指南
- [ ] AI 调试指南

#### 6.5 验收标准
- [ ] 脚手架 Run 起来自带：主题 + 示例 + Debug Panel + AI 接口
- [ ] AI 工具可以用 Skill 调试脚手架项目
- [ ] 所有基于脚手架的项目共享同一套 Skill
- [ ] 文档完整覆盖

---

## 依赖关系

```
Phase 1 (日志+诊断)
  │
  ├──→ Phase 2 (Bridge 重构) ──→ Phase 3 (Debug Panel)
  │                                    │
  │                                    ↓
  ├──→ Phase 4 (Cache 独立)        Phase 5 (AI 接口)
  │                                    │
  └────────────────────────────────────┘
                                       │
                                       ↓
                                  Phase 6 (脚手架+Skill)
```

Phase 1 是基础，Phase 2 和 Phase 4 可以并行，Phase 3 和 Phase 5 依赖 Phase 2，Phase 6 汇总所有。

---

## 工期估算

| Phase | 内容 | 预计工期 | 可并行 |
|-------|------|---------|--------|
| Phase 1 | 日志 + 诊断 | 1 周 | - |
| Phase 2 | Bridge 重构 | 1-2 周 | 与 Phase 4 并行 |
| Phase 3 | Debug Panel | 1 周 | 与 Phase 5 并行 |
| Phase 4 | Cache 独立 | 1 周 | 与 Phase 2 并行 |
| Phase 5 | AI 接口 | 1 周 | 与 Phase 3 并行 |
| Phase 6 | 脚手架 + Skill | 1 周 | - |
| **总计** | | **4-6 周** | |
