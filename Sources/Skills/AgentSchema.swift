import Foundation

// MARK: - Data Models

extension AgentSchema {

    public struct FrameworkCapability: Codable, Sendable {
        public let name: String
        public let category: String
        public let description: String
        public let debuggingMethods: [String]
        public let commonIssues: [IssueSolution]
        public let apiEndpoints: [APIEndpoint]

        public init(
            name: String,
            category: String,
            description: String,
            debuggingMethods: [String],
            commonIssues: [IssueSolution],
            apiEndpoints: [APIEndpoint] = []
        ) {
            self.name = name
            self.category = category
            self.description = description
            self.debuggingMethods = debuggingMethods
            self.commonIssues = commonIssues
            self.apiEndpoints = apiEndpoints
        }
    }

    public struct IssueSolution: Codable, Sendable {
        public let symptom: String
        public let cause: String
        public let solution: String

        public init(symptom: String, cause: String, solution: String) {
            self.symptom = symptom
            self.cause = cause
            self.solution = solution
        }
    }

    public struct APIEndpoint: Codable, Sendable {
        public let method: String
        public let path: String
        public let description: String
        public let parameters: [String: String]

        public init(method: String, path: String, description: String, parameters: [String: String] = [:]) {
            self.method = method
            self.path = path
            self.description = description
            self.parameters = parameters
        }
    }
}

// MARK: - AgentSchema

/// AI Agent 能力 Schema
/// 给 AI Agent 看的框架能力清单：调试手段、功能介绍、排查 Bug 方法
public actor AgentSchema {
    public static let shared = AgentSchema()

    private var capabilities: [String: FrameworkCapability] = [:]

    public init() {
        for cap in Self.builtinCapabilities {
            capabilities[cap.name] = cap
        }
    }

    public func getFullSchema() -> [FrameworkCapability] {
        Array(capabilities.values).sorted { $0.category < $1.category }
    }

    public func getCapabilities(category: String) -> [FrameworkCapability] {
        capabilities.values.filter { $0.category == category }.sorted { $0.name < $1.name }
    }

    public func getTroubleshootingGuide(issue: String) -> [IssueSolution] {
        capabilities.values.flatMap { cap in
            cap.commonIssues.filter {
                $0.symptom.localizedCaseInsensitiveContains(issue) ||
                $0.cause.localizedCaseInsensitiveContains(issue)
            }
        }
    }

    public func getAPIGuide() -> [APIEndpoint] {
        let httpAPI = Self.httpAPIReference
        let moduleAPIs = capabilities.values.flatMap { $0.apiEndpoints }
        return (httpAPI + moduleAPIs).sorted { $0.path < $1.path }
    }

    public func register(_ capability: FrameworkCapability) {
        capabilities[capability.name] = capability
    }

    public func unregister(_ name: String) {
        capabilities.removeValue(forKey: name)
    }

    public func get(_ name: String) -> FrameworkCapability? {
        capabilities[name]
    }
}

// MARK: - Built-in Capabilities

extension AgentSchema {

    private static let builtinCapabilities: [FrameworkCapability] = [
        bridgeCapability,
        cacheCapability,
        messageCapability,
        aiDebugCapability,
        themeCapability,
        commandParserCapability,
        infrastructureCapability
    ]

    // MARK: - Bridge

    private static let bridgeCapability = FrameworkCapability(
        name: "Bridge",
        category: "core",
        description: "JS-Native 通信桥梁。41 个 Handler 覆盖硬件访问（相机/蓝牙/定位/传感器）、媒体操作（音频/视频/图片）、页面导航（打开/关闭/返回）、系统信息查询、剪贴板读写、文件管理、语音识别/合成、手势拦截、屏幕截图、权限管理等。通过 HandlerRegistry 注册与发现，每个 Handler 携带完整的元数据（参数定义、返回类型、权限要求、分类标签）。",
        debuggingMethods: [
            "POST /tools/list_handlers — 列出所有已注册 Handler 及元数据（支持按 category 过滤）",
            "POST /tools/get_handler_detail — 查询单个 Handler 的完整参数、返回类型、权限要求",
            "POST /tools/execute_handler — 通过 AI HTTP 接口直接执行 Handler（参数校验 + 元数据验证）",
            "查看 StructuredLogger 中 category=bridge 的日志，追踪 JS 调用链路",
            "检查 HandlerRegistry.shared.count 确认注册数量",
            "HandlerMetaRegistry 自动扫描并注册所有 Handler 元数据"
        ],
        commonIssues: [
            IssueSolution(
                symptom: "JS 调用 Handler 不响应",
                cause: "Handler 未注册到 HandlerRegistry，或 action 名称与 JS 端不一致",
                solution: "通过 POST /tools/list_handlers 确认 Handler 已注册；检查 JS 端调用的 action 名称拼写；确认 HandlerMetaRegistry 扫描完成"
            ),
            IssueSolution(
                symptom: "Handler 参数格式错误",
                cause: "JS 传入的参数类型与 Handler 定义的参数类型不匹配",
                solution: "通过 POST /tools/get_handler_detail?name=<action> 查看参数定义；检查 JS 端传入的 JSON 格式；使用 execute_handler 的参数校验功能"
            ),
            IssueSolution(
                symptom: "权限相关 Handler 调用失败",
                cause: "Handler 需要的系统权限未授予（如相机、定位、蓝牙）",
                solution: "检查 Info.plist 中是否配置对应权限描述；使用 PermissionHandler 查询当前权限状态；引导用户在系统设置中授权"
            ),
            IssueSolution(
                symptom: "Handler 注册数量不对",
                cause: "HandlerMetaRegistry 扫描时机不对，或部分 Handler 类未编译进目标",
                solution: "确认所有 Handler 文件已加入 Target Membership；在 EngineBootstrap 完成后检查 HandlerRegistry.shared.count"
            )
        ],
        apiEndpoints: [
            APIEndpoint(method: "POST", path: "/tools/list_handlers", description: "列出所有 Handler 元数据", parameters: ["category": "可选，按分类过滤"]),
            APIEndpoint(method: "POST", path: "/tools/get_handler_detail", description: "查询单个 Handler 详情", parameters: ["name": "必填，Handler action 名称"]),
            APIEndpoint(method: "POST", path: "/tools/execute_handler", description: "执行 Handler（参数校验+元数据验证）", parameters: ["name": "必填", "params": "可选，Handler 参数 JSON"])
        ]
    )

    // MARK: - Cache

    private static let cacheCapability = FrameworkCapability(
        name: "Cache",
        category: "core",
        description: "三级缓存系统：内存缓存（MemoryCache，LRU 淘汰）、磁盘缓存（DiskCache，文件持久化）、混合缓存（HybridCache，内存优先+磁盘回退）。支持离线资源缓存（Manifest 驱动）、网页缩略图生成、资源预下载、缓存规则管理（URL 匹配 + Glob 模式）、URLScheme 拦截缓存。通过 CacheManager 统一管理全局统计（命中率、容量、条目数）。",
        debuggingMethods: [
            "POST /tools/get_cache_stats — 查看缓存统计（命中率/内存/磁盘 分项数据）",
            "POST /tools/get_cache_entries — 查看缓存相关日志条目（支持 key 前缀过滤）",
            "POST /tools/clear_cache — 清除缓存（支持按前缀选择性清除或全量清除）",
            "检查 CacheManager.shared 的 getGlobalStatistics() 查看全局缓存状态",
            "查看 StructuredLogger 中 category=cache 的日志"
        ],
        commonIssues: [
            IssueSolution(
                symptom: "缓存命中率低",
                cause: "缓存 key 生成策略不合理，或缓存容量设置过小导致频繁淘汰",
                solution: "通过 get_cache_stats 查看命中率；检查 CacheKeyGenerator 的 key 生成规则；增大内存缓存容量配置"
            ),
            IssueSolution(
                symptom: "磁盘空间不足",
                cause: "磁盘缓存未设置上限，或离线资源累积过多",
                solution: "使用 clear_cache 清理；配置 DiskCache 的最大容量；检查 WebPageOfflineCacheManager 的离线页面数量"
            ),
            IssueSolution(
                symptom: "缓存数据不一致",
                cause: "内存缓存与磁盘缓存数据不同步",
                solution: "使用 HybridCache 确保读写穿透；检查缓存更新时机是否在数据变更后触发"
            ),
            IssueSolution(
                symptom: "URLScheme 缓存拦截不生效",
                cause: "Manifest 未正确配置或 CacheURLSchemeHandler 未注册到 WKWebView",
                solution: "检查 ManifestStore 中是否有对应 URL 的缓存规则；确认 WebView configuration 注册了 CacheURLSchemeHandler"
            )
        ],
        apiEndpoints: [
            APIEndpoint(method: "POST", path: "/tools/get_cache_stats", description: "获取缓存统计（命中率/内存/磁盘）", parameters: [:]),
            APIEndpoint(method: "POST", path: "/tools/get_cache_entries", description: "查看缓存日志条目", parameters: ["filter": "可选，按 key 前缀过滤"]),
            APIEndpoint(method: "POST", path: "/tools/clear_cache", description: "清除缓存", parameters: ["prefix": "可选，按前缀清除，省略则全量清除"])
        ]
    )

    // MARK: - Message

    private static let messageCapability = FrameworkCapability(
        name: "Message",
        category: "core",
        description: "消息推送引擎。支持多渠道（Bark 推送、Webhook 回调），可扩展 MessageChannel 协议。内置消息处理流水线（Markdown 渲染、级别分类、角标更新、自动复制、归档存储、静音过滤）。支持消息路由（URL 跳转/AppId 导航/DeepLink）、持久化存储（UserDefaultsMessageStore）、未读计数。通过 MessageEngine 统一管理发送/接收/统计。",
        debuggingMethods: [
            "POST /tools/get_message_stats — 查看消息统计（接收/发送/失败/排队 + 按渠道分组）",
            "POST /tools/send_test_push — 通过 Bark 渠道发送测试推送",
            "POST /tools/get_config — 查看 Message 模块配置（注册渠道数、接收总数、未读数）",
            "检查 MessageEngine.shared 的 getRegisteredChannels() 确认渠道注册状态",
            "查看 StructuredLogger 中 category=message 的日志"
        ],
        commonIssues: [
            IssueSolution(
                symptom: "推送不到达",
                cause: "Bark 渠道未注册，或服务器 URL / Key 配置错误",
                solution: "通过 get_message_stats 查看发送失败数；检查 EngineBootstrap 中 BarkChannel 的 serverURL 和 key 配置；使用 send_test_push 测试连通性"
            ),
            IssueSolution(
                symptom: "Token 无效",
                cause: "Bark Key 过期或格式错误",
                solution: "检查 UserDefaults 中 com.webbridgekit.bark.key 的值；确认 Key 与 Bark 服务端匹配；重新配置 Bark Key"
            ),
            IssueSolution(
                symptom: "消息处理流水线异常",
                cause: "某个 Processor 抛出异常导致后续 Processor 不执行",
                solution: "查看 StructuredLogger 中的错误日志；逐个禁用 Processor 排查；检查 Processor 的处理逻辑是否有边界情况"
            ),
            IssueSolution(
                symptom: "Webhook 回调失败",
                cause: "网络不可达或目标服务器返回错误",
                solution: "检查网络连接；通过 get_message_stats 查看 byChannel 中的 failed 计数；确认 Webhook URL 可达"
            )
        ],
        apiEndpoints: [
            APIEndpoint(method: "POST", path: "/tools/get_message_stats", description: "获取消息统计", parameters: [:]),
            APIEndpoint(method: "POST", path: "/tools/send_test_push", description: "发送测试 Bark 推送", parameters: ["title": "必填", "body": "必填", "group": "可选", "url": "可选"])
        ]
    )

    // MARK: - AI Debug

    private static let aiDebugCapability = FrameworkCapability(
        name: "AI Debug",
        category: "debug",
        description: "AI 调试 HTTP 服务。运行在本地 :8765 端口，提供 RESTful API 供 AI Agent 调用。内置 13 个调试工具（查询类：list_handlers, get_handler_detail, get_cache_stats, get_cache_entries, get_message_stats, get_recent_errors, get_config, get_diagnostic_report, read_file；操作类：execute_handler, clear_cache, send_test_push, reload_config）。支持 MCP 协议端点用于 LLM 集成。通过 AIRouter 路由请求，AIHTTPServer 管理 TCP 连接。",
        debuggingMethods: [
            "GET /health — 检查 AI HTTP 服务是否运行",
            "GET /tools — 列出所有已注册的调试工具",
            "POST /tools/:name — 执行指定调试工具",
            "POST /mcp — MCP 协议端点（用于 LLM 集成）",
            "POST /tools/get_diagnostic_report — 获取完整诊断报告（Handler 数、缓存状态、消息统计、系统信息）",
            "POST /tools/get_config — 获取框架完整配置快照",
            "POST /tools/get_recent_errors — 查看最近错误日志"
        ],
        commonIssues: [
            IssueSolution(
                symptom: "HTTP 服务启动失败（端口 8765）",
                cause: "端口被占用或 socket 创建失败",
                solution: "检查端口占用情况；重启应用释放端口；查看 EngineBootstrap 日志中的 AI Engine 启动状态"
            ),
            IssueSolution(
                symptom: "工具执行超时",
                cause: "工具内部操作耗时过长（如大文件读取、网络请求）",
                solution: "检查工具参数（如 read_file 的文件大小限制 1MB）；查看 StructuredLogger 中的执行日志"
            ),
            IssueSolution(
                symptom: "MCP 协议调用异常",
                cause: "请求格式不符合 MCP 规范",
                solution: "确认 MCP 请求 JSON 结构正确；检查 AIRouter 的路由匹配逻辑；查看服务端错误日志"
            )
        ],
        apiEndpoints: [
            APIEndpoint(method: "GET", path: "/health", description: "健康检查", parameters: [:]),
            APIEndpoint(method: "GET", path: "/tools", description: "列出所有调试工具", parameters: [:]),
            APIEndpoint(method: "POST", path: "/tools/:name", description: "执行调试工具", parameters: ["name": "工具名称", "...": "工具参数"]),
            APIEndpoint(method: "POST", path: "/mcp", description: "MCP 协议端点", parameters: ["method": "MCP 方法名", "params": "方法参数"])
        ]
    )

    // MARK: - Theme

    private static let themeCapability = FrameworkCapability(
        name: "Theme",
        category: "ui",
        description: "主题管理系统。支持 3 种模式切换：light（浅色）、dark（深色）、system（跟随系统）。通过 ThemeManager actor 管理主题状态，支持观察者模式实时通知主题变更。内置主题组件库（ThemeButton, ThemeCard, ThemeBadge, ThemeGradientView, ThemeSectionHeader, ThemeEmptyState）。支持 Lucide 图标集。",
        debuggingMethods: [
            "POST /tools/get_config — 查看当前 Theme 配置（system 配置中包含当前主题）",
            "调用 ThemeManager.shared.getMode() 查询当前模式",
            "调用 ThemeManager.shared.getTheme() 获取当前 Theme 对象（含 isDark 标记）",
            "检查 ThemeManager 观察者回调是否触发"
        ],
        commonIssues: [
            IssueSolution(
                symptom: "主题切换不生效",
                cause: "ThemeManager.apply() 未调用，或 Window 未应用主题",
                solution: "确认调用了 ThemeManager.shared.apply(.dark)；检查 applyToWindow() 是否执行；确认观察者回调中更新了 UI"
            ),
            IssueSolution(
                symptom: "system 模式下主题不跟随系统",
                cause: "未正确读取 UIScreen.main.traitCollection.userInterfaceStyle",
                solution: "检查 ThemeManager.getTheme() 的 system 模式逻辑；确认在 traitCollectionDidChange 中触发了主题更新"
            ),
            IssueSolution(
                symptom: "主题组件样式不一致",
                cause: "部分视图未使用主题组件，或硬编码了颜色值",
                solution: "统一使用 Theme 组件库；检查是否有硬编码 UIColor；使用 Theme.isDark 判断分支"
            )
        ],
        apiEndpoints: []
    )

    // MARK: - CommandParser

    private static let commandParserCapability = FrameworkCapability(
        name: "CommandParser",
        category: "core",
        description: "口令解析引擎。从剪贴板监控输入，解析 JSON/URL/Base64 编码的命令载荷。支持命令签名验证（防篡改）、时间戳校验（防重放）、Nonce 去重（防重复执行）。通过 CommandDecoderRegistry 管理解码器，CommandRouter 负责路由分发。可配置最大载荷大小、最大有效期、允许的 URL Scheme。",
        debuggingMethods: [
            "构造测试口令字符串，调用 CommandParser.shared.parse() 验证解析结果",
            "检查 CommandParserConfiguration 的配置参数（maxPayloadSize, maxAge, allowedSchemes）",
            "查看 StructuredLogger 中与 CommandParser 相关的日志",
            "测试不同编码格式（JSON/URL/Base64）的命令输入"
        ],
        commonIssues: [
            IssueSolution(
                symptom: "口令解析失败",
                cause: "输入格式不符合任何已注册的 CommandDecoder，或载荷超过大小限制",
                solution: "检查输入是否为合法 JSON/URL/Base64 格式；确认载荷大小 <= maxPayloadSize（默认 4096）；查看 CommandDecoderRegistry 中注册的解码器"
            ),
            IssueSolution(
                symptom: "签名验证失败",
                cause: "签名密钥不匹配或载荷被篡改",
                solution: "确认 CommandSignatureVerifier 配置正确；检查签名算法是否一致；enableSignatureVerification 确认为 true"
            ),
            IssueSolution(
                symptom: "命令重复执行",
                cause: "Nonce 去重缓存溢出或时间戳校验未启用",
                solution: "确认 enableTimestampValidation 为 true；检查 Nonce 缓存大小（maxNonceCacheSize 默认 1000）"
            )
        ],
        apiEndpoints: []
    )

    // MARK: - Infrastructure

    private static let infrastructureCapability = FrameworkCapability(
        name: "Infrastructure",
        category: "infrastructure",
        description: "基础设施层。包含结构化日志系统（StructuredLogger，多级别日志 + 环形缓冲区 + 按类别/级别查询）和诊断引擎（DiagnosticEngine，自动收集 Handler 数量、缓存统计、消息统计、内存使用、系统版本、运行时间等。EnvironmentInfo 提供设备环境信息，ErrorContext 记录错误上下文。LogPipeline 支持日志管道处理。",
        debuggingMethods: [
            "POST /tools/get_recent_errors — 获取最近错误/警告日志（支持按级别过滤）",
            "POST /tools/get_diagnostic_report — 生成完整诊断报告",
            "StructuredLogger.shared.query(category:limit:) — 按类别查询日志",
            "StructuredLogger.shared.query(minLevel:limit:) — 按级别查询日志",
            "StructuredLogger.shared.getStats() — 获取日志统计（总条目/错误数/警告数）",
            "DiagnosticEngine 生成综合诊断报告"
        ],
        commonIssues: [
            IssueSolution(
                symptom: "日志缓冲区溢出",
                cause: "日志产生速度过快，超出环形缓冲区容量",
                solution: "调高 StructuredLogger 的缓冲区大小；提高 minLevel 过滤低级别日志；使用 clearBuffer() 定期清理"
            ),
            IssueSolution(
                symptom: "诊断报告信息不全",
                cause: "部分模块未初始化或统计数据未更新",
                solution: "确认所有 Engine 在 DiagnosticEngine 运行前已完成初始化；检查各模块的统计方法是否正常返回"
            ),
            IssueSolution(
                symptom: "日志级别配置不当导致性能问题",
                cause: "生产环境使用 .verbose 级别，日志量过大",
                solution: "生产环境设置 minLevel 为 .warning 或 .error；通过 WebBridgeKitConfiguration.Debug.isLoggingEnabled 控制开关"
            )
        ],
        apiEndpoints: [
            APIEndpoint(method: "POST", path: "/tools/get_recent_errors", description: "获取最近错误日志", parameters: ["count": "可选，最大条目数默认 20", "level": "可选，最低级别"]),
            APIEndpoint(method: "POST", path: "/tools/get_diagnostic_report", description: "生成完整诊断报告", parameters: [:])
        ]
    )

    // MARK: - HTTP API Reference

    private static let httpAPIReference: [APIEndpoint] = [
        APIEndpoint(method: "GET", path: "/health", description: "健康检查，返回服务运行状态", parameters: [:]),
        APIEndpoint(method: "GET", path: "/tools", description: "列出所有已注册的调试工具及描述", parameters: [:]),
        APIEndpoint(method: "POST", path: "/tools/:name", description: "执行指定调试工具，参数以 JSON Body 传入", parameters: ["name": "工具名称，如 list_handlers / get_cache_stats"]),
        APIEndpoint(method: "POST", path: "/mcp", description: "MCP 协议端点，用于 LLM 集成调用", parameters: ["method": "MCP 方法名", "params": "方法参数对象"])
    ]
}
