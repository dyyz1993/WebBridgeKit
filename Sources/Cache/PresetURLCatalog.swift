import Foundation

// MARK: - 预设 URL 分类
public enum PresetCategory: String, CaseIterable, Codable {
    case htmlPages = "htmlPages"
    case webApps = "webApps"
    case apiEndpoints = "apiEndpoints"
    case staticResources = "staticResources"
    case websockets = "websockets"
    case mcpServers = "mcpServers"
    case testing = "testing"
    case performance = "performance"

    public var displayName: String {
        switch self {
        case .htmlPages: return "HTML 页面"
        case .webApps: return "Web 应用"
        case .apiEndpoints: return "API 接口"
        case .staticResources: return "静态资源"
        case .websockets: return "WebSocket"
        case .mcpServers: return "MCP 服务"
        case .testing: return "测试工具"
        case .performance: return "性能测试"
        }
    }

    public var iconName: String {
        switch self {
        case .htmlPages: return "file-text"
        case .webApps: return "globe"
        case .apiEndpoints: return "code"
        case .staticResources: return "image"
        case .websockets: return "wifi"
        case .mcpServers: return "bot"
        case .testing: return "flask-conical"
        case .performance: return "gauge"
        }
    }

    public var sortPriority: Int {
        switch self {
        case .htmlPages: return 1
        case .webApps: return 2
        case .apiEndpoints: return 3
        case .staticResources: return 4
        case .websockets: return 5
        case .mcpServers: return 6
        case .testing: return 7
        case .performance: return 8
        }
    }
}

// MARK: - 单条预设 URL
public struct PresetURLItem: Identifiable, Equatable, Codable {
    public let id: String
    public let url: String
    public let title: String
    public let description: String
    public let category: PresetCategory
    public let urlType: URLType
    public let tags: [String]
    public let isRecommended: Bool

    public init(
        id: String = UUID().uuidString,
        url: String,
        title: String,
        description: String,
        category: PresetCategory,
        urlType: URLType? = nil,
        tags: [String] = [],
        isRecommended: Bool = false
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.description = description
        self.category = category
        self.urlType = urlType ?? URLType.detect(from: url)
        self.tags = tags
        self.isRecommended = isRecommended
    }
}

// MARK: - 预设 URL 目录
public enum PresetURLCatalog {

    public static let allItems: [PresetURLItem] = [
        // === HTML Pages (5) ===
        PresetURLItem(
            url: "https://example.com",
            title: "Example Domain",
            description: "ICANN 保留的示例域名，用于文档和测试。最简单的 HTML 页面，适合验证基础网络连接和缓存功能。",
            category: .htmlPages,
            tags: ["示例", "基础", "ICANN"],
            isRecommended: true
        ),
        PresetURLItem(
            url: "https://httpbin.org/html",
            title: "HTTPBin HTML",
            description: "HTTPBin 提供的 HTML 测试页面，包含图片、链接等元素。常用于测试 WebView 渲染和资源加载。",
            category: .htmlPages,
            tags: ["测试", "HTTP", "渲染"]
        ),
        PresetURLItem(
            url: "https://www.wikipedia.org",
            title: "Wikipedia",
            description: "维基百科首页。大型复杂 HTML 页面，包含大量 CSS/JS/图片资源，适合测试完整页面缓存。",
            category: .htmlPages,
            tags: ["百科", "复杂页面", "大量资源"]
        ),
        PresetURLItem(
            url: "https://github.com",
            title: "GitHub",
            description: "GitHub 首页。SPA 应用，包含动态加载内容。可测试 JavaScript 执行和 DOM 缓存。",
            category: .htmlPages,
            tags: ["代码托管", "SPA", "动态内容"]
        ),
        PresetURLItem(
            url: "https://developer.mozilla.org/zh-CN/",
            title: "MDN Web Docs",
            description: "Mozilla 开发者网络文档（中文版）。技术文档站点，资源丰富，适合测试离线文档缓存。",
            category: .htmlPages,
            tags: ["文档", "MDN", "中文", "离线阅读"]
        ),

        // === Web Apps / SPA (4) ===
        PresetURLItem(
            url: "https://chat.openai.com",
            title: "ChatGPT",
            description: "OpenAI ChatGPT 界面。典型的现代 SPA 应用，重度依赖 JavaScript 和 WebSocket 连接。",
            category: .webApps,
            tags: ["AI", "聊天", "SPA"],
            isRecommended: true
        ),
        PresetURLItem(
            url: "https://excalidraw.com",
            title: "Excalidraw",
            description: "开源在线白板工具。手绘风格的画板应用，测试 Canvas 渲染和实时协作缓存。",
            category: .webApps,
            tags: ["白板", "绘图", "Canvas", "开源"]
        ),
        PresetURLItem(
            url: "https://stackblitz.com",
            title: "StackBlitz",
            description: "在线 IDE 和开发环境。基于 WebContainers 技术，可在浏览器中运行完整 Node.js 环境。",
            category: .webApps,
            tags: ["IDE", "在线开发", "WebContainer"]
        ),
        PresetURLItem(
            url: "https://figma.com/community",
            title: "Figma Community",
            description: "Figma 社区设计资源库。大型设计平台，包含大量 SVG/图片资源。",
            category: .webApps,
            tags: ["设计", "Figma", "社区", "资源"]
        ),

        // === API Endpoints (5) ===
        PresetURLItem(
            url: "https://httpbin.org/get",
            title: "HTTPBin GET",
            description: "HTTPBin GET 测试端点。返回请求头、参数、Origin 等信息。API 测试的首选工具。",
            category: .apiEndpoints,
            urlType: .apiEndpoint,
            tags: ["HTTP", "GET", "测试", "调试"],
            isRecommended: true
        ),
        PresetURLItem(
            url: "https://httpbin.org/json",
            title: "HTTPBin JSON",
            description: "返回示例 JSON 数据的对象。包含 slideshow、widget、integer 等字段，适合测试 JSON 解析。",
            category: .apiEndpoints,
            urlType: .apiEndpoint,
            tags: ["JSON", "示例数据", "解析"]
        ),
        PresetURLItem(
            url: "https://api.github.com/zen",
            title: "GitHub Zen API",
            description: "GitHub 的禅语 API。每次请求返回一条随机励志语录。最简 API 测试目标。",
            category: .apiEndpoints,
            urlType: .apiEndpoint,
            tags: ["GitHub", "API", "文本", "简单"]
        ),
        PresetURLItem(
            url: "https://jsonplaceholder.typicode.com/posts",
            title: "JSONPlaceholder Posts",
            description: "JSONPlaceholder 的文章列表端点。返回 100 条博客文章数据，适合测试列表渲染和分页。",
            category: .apiEndpoints,
            urlType: .apiEndpoint,
            tags: ["REST", "假数据", "帖子", "列表"]
        ),
        PresetURLItem(
            url: "https://pokeapi.co/api/v2/pokemon/ditto",
            title: "PokeAPI",
            description: "Pokémon API 返回 Ditto 的详细数据。嵌套 JSON 结构，包含能力、形态、游戏版本等信息。",
            category: .apiEndpoints,
            urlType: .apiEndpoint,
            tags: ["游戏", "Pokemon", "REST", "嵌套JSON"]
        ),

        // === Static Resources (5) ===
        PresetURLItem(
            url: "https://cdn.jsdelivr.net/npm/vue@3/dist/vue.global.prod.js",
            title: "Vue 3 CDN (Production)",
            description: "Vue 3 完整版生产构建（~260KB gzip）。全球最受欢迎的前端框架之一，CDN 分发。",
            category: .staticResources,
            tags: ["Vue", "JavaScript", "CDN", "前端框架"]
        ),
        PresetURLItem(
            url: "https://cdn.tailwindcss.com/3.4.1/tailwind.min.css",
            title: "Tailwind CSS CDN",
            description: "Tailwind CSS v3.4.1 压缩版（~9KB gzip）。实用优先的 CSS 框架，通过 CDN 即用。",
            category: .staticResources,
            tags: ["CSS", "Tailwind", "CDN", "样式框架"]
        ),
        PresetURLItem(
            url: "https://fonts.googleapis.com/css2?family=Inter:wght@400;700&display=swap",
            title: "Google Fonts - Inter",
            description: "Google Fonts 的 Inter 字体（400+700 weight）。现代 sans-serif 字体，广泛用于 UI 设计系统。",
            category: .staticResources,
            tags: ["字体", "Google Fonts", "Inter", "排版"]
        ),
        PresetURLItem(
            url: "https://cdn.jsdelivr.net/npm/@appbaseio/reactivesearch@3.41.0/dist/manifest.json",
            title: "ReactiveSearch Manifest",
            description: "ReactiveSearch 库的 App Manifest 文件。可用于测试 Manifest 缓存的解析和存储流程。",
            category: .staticResources,
            urlType: .manifest,
            tags: ["Manifest", "PWA", "ReactiveSearch", "配置"]
        ),
        PresetURLItem(
            url: "https://raw.githubusercontent.com/nicehash/NiceHashQuickMiner/master/manifest.json",
            title: "NiceHash Miner Manifest",
            description: "NiceHash Quick Miner 的 Manifest 文件。包含应用元数据和资源映射，测试完整 Manifest 缓存链路。",
            category: .staticResources,
            urlType: .manifest,
            tags: ["Manifest", "挖矿", "GitHub Raw", "配置"]
        ),

        // === WebSocket (2) ===
        PresetURLItem(
            url: "wss://echo.websocket.events",
            title: "WebSocket Echo Server",
            description: "WebSocket.org 提供的 Echo 服务器。发送什么消息就回显什么，WS 连接测试的标准工具。",
            category: .websockets,
            tags: ["Echo", "回显", "WS", "连接测试"],
            isRecommended: true
        ),
        PresetURLItem(
            url: "wss://ws.postmanlatest.com/ping",
            title: "Postman WebSocket Ping",
            description: "Postman 的 WebSocket Ping 端点。发送 ping 返回 pong，用于测试 WS 延迟和稳定性。",
            category: .websockets,
            tags: ["Postman", "Ping", "延迟", "WS"]
        ),

        // === MCP Servers (1) ===
        PresetURLItem(
            url: "https://modelcontextprotocol.io/endpoint",
            title: "MCP Official Endpoint",
            description: "Model Context Protocol 官方端点描述。MCP 是 AI 工具调用的开放协议标准。",
            category: .mcpServers,
            tags: ["MCP", "AI", "协议", "工具调用"]
        ),

        // === Testing Tools (2) ===
        PresetURLItem(
            url: "https://web.dev/measure",
            title: "Lighthouse Analysis",
            description: "Google Lighthouse 在线分析工具。输入 URL 可获得性能/可访问性/SEO 评分报告。",
            category: .testing,
            tags: ["Lighthouse", "性能审计", "Google", "评分"]
        ),
        PresetURLItem(
            url: "https://caniuse.com",
            title: "Can I Use",
            description: "浏览器兼容性查询数据库。检查 Web API/CSS/JS 特性在各浏览器的支持情况。",
            category: .testing,
            tags: ["兼容性", "浏览器", "特性查询", "数据库"]
        ),

        // === Performance (1) ===
        PresetURLItem(
            url: "https://pagespeed.web.dev/analysis",
            title: "PageSpeed Insights",
            description: "Google PageSpeed Insights 性能分析工具。提供 Core Web Vitals 评分和优化建议。",
            category: .performance,
            tags: ["性能", "Core Web Vitals", "Google", "优化建议"]
        ),
    ]

    public static var itemsByCategory: [PresetCategory: [PresetURLItem]] {
        Dictionary(grouping: allItems) { $0.category }
    }

    public static var recommendedItems: [PresetURLItem] {
        allItems.filter { $0.isRecommended }
    }

    public static func search(_ query: String) -> [PresetURLItem] {
        let q = query.lowercased()
        guard !q.isEmpty else { return allItems }
        return allItems.filter { item in
            item.title.lowercased().contains(q) ||
            item.description.lowercased().contains(q) ||
            item.url.lowercased().contains(q) ||
            item.tags.contains(where: { $0.lowercased().contains(q) })
        }
    }

    public static func find(id: String) -> PresetURLItem? {
        allItems.first { $0.id == id }
    }
}
