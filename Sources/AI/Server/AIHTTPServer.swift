import Foundation

/// Lightweight HTTP server for AI tool integration
/// Listens on a local port and provides REST API endpoints
public actor AIHTTPServer {
    public static let defaultPort: UInt16 = 8765
    
    private var serverSocket: Int32 = -1
    private var isRunning = false
    private let port: UInt16
    private let router: AIRouter
    private let configuration: AIServerConfiguration
    
    /// Callback for server events
    public var onServerEvent: (@Sendable (AIServerEvent) -> Void)?
    
    public init(
        port: UInt16 = AIHTTPServer.defaultPort,
        configuration: AIServerConfiguration = .default
    ) {
        self.port = port
        self.router = AIRouter()
        self.configuration = configuration
    }
    
    // MARK: - Server Lifecycle
    
    /// Start the HTTP server
    public func start() async throws {
        guard !isRunning else { return }
        
        serverSocket = socket(AF_INET, SOCK_STREAM, 0)
        guard serverSocket >= 0 else {
            throw AIError.serverStartFailed(reason: "Failed to create socket")
        }
        
        // Allow port reuse
        var reuse: Int32 = 1
        setsockopt(serverSocket, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout.size(ofValue: reuse)))
        
        // Bind
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(port).bigEndian
        addr.sin_addr = in_addr(s_addr: in_addr_t(0))  // 0.0.0.0
        
        let addrSize = socklen_t(MemoryLayout.size(ofValue: addr))
        let bindResult = withUnsafePointer(to: &addr) { ptr in
            bind(serverSocket, UnsafeRawPointer(ptr).assumingMemoryBound(to: sockaddr.self), addrSize)
        }
        
        guard bindResult == 0 else {
            close(serverSocket)
            throw AIError.serverStartFailed(reason: "Failed to bind to port \(port)")
        }
        
        // Listen
        guard listen(serverSocket, 10) == 0 else {
            close(serverSocket)
            throw AIError.serverStartFailed(reason: "Failed to listen on port \(port)")
        }
        
        isRunning = true
        onServerEvent?(.started(port: port))
        
        // Accept connections in background
        Task {
            await acceptConnections()
        }
    }
    
    /// Stop the HTTP server
    public func stop() {
        guard isRunning else { return }
        isRunning = false
        
        if serverSocket >= 0 {
            close(serverSocket)
            serverSocket = -1
        }
        
        onServerEvent?(.stopped)
    }
    
    // MARK: - Route Registration
    
    /// Register a route handler
    public func registerRoute(
        method: HTTPMethod,
        path: String,
        handler: @escaping @Sendable (AIRequest) async -> AIResponse
    ) async {
        await router.register(method: method, path: path, handler: handler)
    }
    
    /// Register default API routes
    public func registerDefaultRoutes() async {
        await registerRoute(method: .GET, path: "/health") { _ in
            AIResponse(statusCode: 200, body: ["status": "ok", "version": "1.0.0"])
        }
        
        await registerRoute(method: .GET, path: "/tools") { [self] _ in
            let tools = await self.router.listTools()
            return AIResponse(statusCode: 200, body: ["tools": tools])
        }
        
        await registerRoute(method: .POST, path: "/tools/:name") { [self] request in
            await self.router.executeTool(name: request.pathComponents.last ?? "", params: request.body)
        }
        
        await registerRoute(method: .POST, path: "/mcp") { [self] request in
            await self.router.handleMCP(request)
        }
    }
    
    // MARK: - Private Methods
    
    private func acceptConnections() async {
        while isRunning {
            var clientAddr = sockaddr()
            var clientAddrLen = socklen_t(MemoryLayout.size(ofValue: clientAddr))
            
            let clientSocket = accept(serverSocket, &clientAddr, &clientAddrLen)
            guard clientSocket >= 0 else { continue }
            
            Task {
                await handleClient(socket: clientSocket)
            }
        }
    }
    
    private func handleClient(socket: Int32) async {
        defer { close(socket) }
        
        // Read request
        var buffer = [UInt8](repeating: 0, count: 8192)
        let bytesRead = recv(socket, &buffer, buffer.count, 0)
        guard bytesRead > 0 else { return }
        
        let requestData = Data(buffer[0..<bytesRead])
        guard let requestString = String(data: requestData, encoding: .utf8) else { return }
        
        // Parse request
        guard let request = parseHTTPRequest(requestString) else {
            sendResponse(socket: socket, response: AIResponse(statusCode: 400, body: ["error": "Bad request"]))
            return
        }
        
        // Route request
        let response = await router.route(request)
        
        // Send response
        sendResponse(socket: socket, response: response)
    }
    
    private func parseHTTPRequest(_ raw: String) -> AIRequest? {
        let lines = raw.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else { return nil }
        
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2 else { return nil }
        
        let method = String(parts[0])
        let path = String(parts[1])
        
        // Parse headers
        var headers: [String: String] = [:]
        var bodyStart = 0
        for (index, line) in lines.enumerated() {
            if line.isEmpty {
                bodyStart = index + 1
                break
            }
            let headerParts = line.split(separator: ":", maxSplits: 1)
            if headerParts.count == 2 {
                headers[headerParts[0].trimmingCharacters(in: .whitespaces)] = headerParts[1].trimmingCharacters(in: .whitespaces)
            }
        }
        
        // Parse body
        var body: [String: Any] = [:]
        if bodyStart < lines.count {
            let bodyString = lines[bodyStart...].joined(separator: "\r\n")
            if let bodyData = bodyString.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] {
                body = json
            }
        }
        
        return AIRequest(
            method: HTTPMethod(rawValue: method) ?? .GET,
            path: path,
            headers: headers,
            body: body
        )
    }
    
    private func sendResponse(socket: Int32, response: AIResponse) {
        let bodyData = try? JSONSerialization.data(withJSONObject: response.body)
        let bodyString = bodyData.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        
        let httpResponse = """
        HTTP/1.1 \(response.statusCode) \(HTTPStatusMessage.forCode(response.statusCode))\r
        Content-Type: application/json\r
        Content-Length: \(bodyString.utf8.count)\r
        Access-Control-Allow-Origin: *\r
        Access-Control-Allow-Methods: GET, POST, OPTIONS\r
        Access-Control-Allow-Headers: Content-Type\r
        \r
        \(bodyString)
        """
        
        let responseData = Array(httpResponse.utf8)
        send(socket, responseData, responseData.count, 0)
    }
}

// MARK: - Supporting Types

public enum HTTPMethod: String, Sendable {
    case GET, POST, PUT, DELETE, OPTIONS, PATCH
}

public struct AIRequest: Sendable {
    public let method: HTTPMethod
    public let path: String
    public let headers: [String: String]
    public let body: [String: Any]
    
    public var pathComponents: [String] {
        path.components(separatedBy: "/").filter { !$0.isEmpty }
    }
}

public struct AIResponse: Sendable {
    public let statusCode: Int
    public let body: [String: Any]
    
    public init(statusCode: Int = 200, body: [String: Any] = [:]) {
        self.statusCode = statusCode
        self.body = body
    }
    
    public static func ok(_ body: [String: Any] = [:]) -> AIResponse {
        AIResponse(statusCode: 200, body: body)
    }
    
    public static func error(_ message: String, code: Int = 400) -> AIResponse {
        AIResponse(statusCode: code, body: ["error": message])
    }
    
    public static func notFound(_ message: String = "Not found") -> AIResponse {
        AIResponse(statusCode: 404, body: ["error": message])
    }
}

public enum AIServerEvent: Sendable {
    case started(port: UInt16)
    case stopped
    case requestReceived(path: String)
    case error(Error)
}

public struct AIServerConfiguration: Sendable {
    public let maxConnections: Int
    public let requestTimeout: TimeInterval
    public let enableCORS: Bool
    public let apiKey: String?
    
    public init(
        maxConnections: Int = 10,
        requestTimeout: TimeInterval = 30,
        enableCORS: Bool = true,
        apiKey: String? = nil
    ) {
        self.maxConnections = maxConnections
        self.requestTimeout = requestTimeout
        self.enableCORS = enableCORS
        self.apiKey = apiKey
    }
    
    public static let `default` = AIServerConfiguration()
}

public enum AIError: Error, LocalizedError {
    case serverStartFailed(reason: String)
    case routeNotFound(path: String)
    case invalidRequest(reason: String)
    case unauthorized
    case toolExecutionFailed(tool: String, reason: String)
    
    public var errorDescription: String? {
        switch self {
        case .serverStartFailed(let reason):
            return "Server start failed: \(reason)"
        case .routeNotFound(let path):
            return "Route not found: \(path)"
        case .invalidRequest(let reason):
            return "Invalid request: \(reason)"
        case .unauthorized:
            return "Unauthorized - check API key"
        case .toolExecutionFailed(let tool, let reason):
            return "Tool '\(tool)' execution failed: \(reason)"
        }
    }
}

private enum HTTPStatusMessage {
    static func forCode(_ code: Int) -> String {
        switch code {
        case 200: return "OK"
        case 201: return "Created"
        case 204: return "No Content"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 403: return "Forbidden"
        case 404: return "Not Found"
        case 500: return "Internal Server Error"
        default: return "Unknown"
        }
    }
}
