import Foundation

/// Built-in AI Agent capability definitions that ship with the framework
public enum BuiltinSkills {

    public static let bridge = AgentSchema.FrameworkCapability(
        name: "Bridge",
        category: "core",
        description: "JS-Native 通信桥梁。41 个 Handler 覆盖硬件访问、媒体操作、页面导航、系统信息、剪贴板、文件管理、语音、手势、权限等。",
        debuggingMethods: [
            "POST /tools/list_handlers",
            "POST /tools/get_handler_detail",
            "POST /tools/execute_handler"
        ],
        commonIssues: [
            AgentSchema.IssueSolution(
                symptom: "JS 调用不响应",
                cause: "Handler 未注册或 action 名称不匹配",
                solution: "检查 list_handlers 确认注册状态"
            )
        ],
        apiEndpoints: [
            AgentSchema.APIEndpoint(method: "POST", path: "/tools/list_handlers", description: "列出所有 Handler")
        ]
    )

    public static let cache = AgentSchema.FrameworkCapability(
        name: "Cache",
        category: "core",
        description: "三级缓存系统：内存/磁盘/混合缓存，离线资源缓存，缓存规则管理。",
        debuggingMethods: [
            "POST /tools/get_cache_stats",
            "POST /tools/clear_cache"
        ],
        commonIssues: [
            AgentSchema.IssueSolution(
                symptom: "缓存命中率低",
                cause: "缓存 key 策略不合理或容量过小",
                solution: "查看 get_cache_stats 调整配置"
            )
        ],
        apiEndpoints: [
            AgentSchema.APIEndpoint(method: "POST", path: "/tools/get_cache_stats", description: "获取缓存统计")
        ]
    )

    public static let message = AgentSchema.FrameworkCapability(
        name: "Message",
        category: "core",
        description: "消息推送引擎，支持 Bark/Webhook 渠道，消息处理流水线。",
        debuggingMethods: [
            "POST /tools/get_message_stats",
            "POST /tools/send_test_push"
        ],
        commonIssues: [
            AgentSchema.IssueSolution(
                symptom: "推送不到达",
                cause: "Bark 渠道未注册或 Key 无效",
                solution: "使用 send_test_push 测试连通性"
            )
        ],
        apiEndpoints: [
            AgentSchema.APIEndpoint(method: "POST", path: "/tools/send_test_push", description: "发送测试推送", parameters: ["title": "必填", "body": "必填"])
        ]
    )

    public static let all: [AgentSchema.FrameworkCapability] = [bridge, cache, message]
}
