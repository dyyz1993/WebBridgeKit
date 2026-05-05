import Foundation

/// Routes AI requests to appropriate handlers
public actor AIRouter {
    private var routes: [RouteKey: @Sendable (AIRequest) async -> AIResponse] = [:]
    private var tools: [String: AITool] = [:]

    private struct RouteKey: Hashable {
        let method: HTTPMethod
        let path: String
    }

    public init() {}

    // MARK: - Route Registration

    public func register(
        method: HTTPMethod,
        path: String,
        handler: @escaping @Sendable (AIRequest) async -> AIResponse
    ) {
        routes[RouteKey(method: method, path: path)] = handler
    }

    // MARK: - Tool Registration

    public func registerTool(_ tool: AITool) {
        tools[tool.name] = tool
    }

    public func listTools() -> [[String: String]] {
        tools.values.map { [
            "name": $0.name,
            "description": $0.description,
            "category": $0.category
        ] }
    }

    // MARK: - Routing

    public func route(_ request: AIRequest) async -> AIResponse {
        // Try exact match first
        let key = RouteKey(method: request.method, path: request.path)
        if let handler = routes[key] {
            return await handler(request)
        }

        // Try parameterized route match
        for (routeKey, handler) in routes where matchRoute(routeKey.path, requestPath: request.path) {
            return await handler(request)
        }

        return AIResponse.notFound("No route found for \(request.method.rawValue) \(request.path)")
    }

    // MARK: - Tool Execution

    public func executeTool(name: String, params: [String: Any]) async -> AIResponse {
        guard let tool = tools[name] else {
            return AIResponse.notFound("Tool '\(name)' not found")
        }

        do {
            let result = try await tool.execute(params: params)
            return AIResponse.ok(["result": result])
        } catch {
            return AIResponse.error(
                "Tool execution failed: \(error.localizedDescription)",
                code: 500
            )
        }
    }

    // MARK: - MCP Protocol

    public func handleMCP(_ request: AIRequest) async -> AIResponse {
        guard let method = request.body["method"] as? String else {
            return AIResponse.error("Missing 'method' in MCP request")
        }

        let params = request.body["params"] as? [String: Any] ?? [:]

        switch method {
        case "tools/list":
            return AIResponse.ok([
                "tools": tools.values.map { $0.toMCPToolDefinition() }
            ])

        case "tools/call":
            guard let toolName = params["name"] as? String else {
                return AIResponse.error("Missing tool name in 'tools/call'")
            }
            let toolParams = params["arguments"] as? [String: Any] ?? [:]
            return await executeTool(name: toolName, params: toolParams)

        case "initialize":
            return AIResponse.ok([
                "protocolVersion": "2024-11-05",
                "capabilities": ["tools": ["listChanged": true]],
                "serverInfo": [
                    "name": "WebBridgeKit-AI",
                    "version": "1.0.0"
                ]
            ])

        default:
            return AIResponse.error("Unknown MCP method: \(method)", code: 400)
        }
    }

    // MARK: - Private Methods

    private func matchRoute(_ routePattern: String, requestPath: String) -> Bool {
        let routeComponents = routePattern.split(separator: "/")
        let pathComponents = requestPath.split(separator: "/")

        guard routeComponents.count == pathComponents.count else { return false }

        for (route, path) in zip(routeComponents, pathComponents) {
            if route.hasPrefix(":") { continue }  // Parameter placeholder
            if route != path { return false }
        }

        return true
    }
}

// MARK: - AI Tool

public struct AITool: Sendable {
    public let name: String
    public let description: String
    public let category: String
    public let parameters: [AIParameter]
    private let executeHandler: @Sendable ([String: Any]) async throws -> Any

    public init(
        name: String,
        description: String,
        category: String = "general",
        parameters: [AIParameter] = [],
        execute: @escaping @Sendable ([String: Any]) async throws -> Any
    ) {
        self.name = name
        self.description = description
        self.category = category
        self.parameters = parameters
        self.executeHandler = execute
    }

    public func execute(params: [String: Any]) async throws -> Any {
        try await executeHandler(params)
    }

    public func toMCPToolDefinition() -> [String: Any] {
        var inputSchema: [String: Any] = [
            "type": "object",
            "properties": parameters.reduce(into: [String: Any]()) { result, param in
                result[param.name] = [
                    "type": param.type,
                    "description": param.description
                ]
            }
        ]

        let required = parameters.filter { $0.required }.map { $0.name }
        if !required.isEmpty {
            inputSchema["required"] = required
        }

        return [
            "name": name,
            "description": description,
            "inputSchema": inputSchema
        ]
    }
}

public struct AIParameter: Sendable {
    public let name: String
    public let type: String
    public let description: String
    public let required: Bool
    public let defaultValue: String?

    public init(
        name: String,
        type: String = "string",
        description: String = "",
        required: Bool = false,
        defaultValue: String? = nil
    ) {
        self.name = name
        self.type = type
        self.description = description
        self.required = required
        self.defaultValue = defaultValue
    }
}
