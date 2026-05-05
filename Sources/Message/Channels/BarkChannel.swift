import Foundation

/// Bark push notification channel
/// Sends push notifications via Bark server (https://github.com/Finb/Bark)
public actor BarkChannel: @preconcurrency MessageChannel {
    public let channelId = "bark"
    public nonisolated(unsafe) var isActive = false
    
    private let serverURL: String
    private let key: String
    private let session: URLSession
    private var configuration: BarkConfiguration
    
    public init(
        serverURL: String = "https://api.day.app",
        key: String,
        configuration: BarkConfiguration = .default
    ) {
        self.serverURL = serverURL.hasSuffix("/") ? String(serverURL.dropLast()) : serverURL
        self.key = key
        self.configuration = configuration
        self.session = URLSession(configuration: .ephemeral)
    }
    
    public func start() async {
        isActive = true
    }
    
    public func stop() async {
        isActive = false
    }
    
    public func send(_ payload: MessagePayload) async throws -> MessageSendResult {
        guard isActive else {
            return .failed(error: .channelNotActive(channelId: channelId))
        }
        
        guard !key.isEmpty else {
            return .failed(error: .channelNotConfigured(channelId: channelId))
        }
        
        let url = try buildBarkURL(payload)
        
        do {
            let (_, response) = try await session.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200:
                    return .success(messageId: payload.id)
                case 401:
                    return .failed(error: .unauthorized)
                case 429:
                    let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                        .flatMap { TimeInterval($0) }
                    return .failed(error: .rateLimited(retryAfter: retryAfter))
                default:
                    return .failed(error: .serverError(
                        statusCode: httpResponse.statusCode,
                        message: "Unexpected status code"
                    ))
                }
            }
            
            return .success(messageId: payload.id)
        } catch {
            return .failed(error: .networkError(underlying: error))
        }
    }
    
    // MARK: - Bark API
    
    /// Send a simple text notification
    public func sendText(
        title: String,
        body: String,
        group: String? = nil,
        sound: String? = nil,
        url: String? = nil
    ) async throws -> MessageSendResult {
        let payload = MessagePayload(
            title: title,
            body: body,
            channel: channelId,
            sound: sound,
            group: group,
            targetURL: url
        )
        return try await send(payload)
    }
    
    /// Test connection to Bark server
    public func testConnection() async throws -> Bool {
        guard let url = URL(string: "\(serverURL)/\(key)/test/test") else {
            return false
        }
        
        let (_, response) = try await session.data(from: url)
        
        if let httpResponse = response as? HTTPURLResponse {
            return httpResponse.statusCode == 200
        }
        return false
    }
    
    // MARK: - Private Methods
    
    private func buildBarkURL(_ payload: MessagePayload) throws -> URL {
        var components: [String] = []
        
        // Base URL + key
        components.append(serverURL)
        components.append(key)
        
        // Title and body (URL encoded)
        let encodedTitle = payload.title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? payload.title
        let encodedBody = payload.body.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? payload.body
        
        components.append(encodedTitle)
        components.append(encodedBody)
        
        // Build URL string
        let urlString = components.joined(separator: "/")
        
        // Add query parameters
        var queryItems: [URLQueryItem] = []
        
        if let sound = payload.sound {
            queryItems.append(URLQueryItem(name: "sound", value: sound))
        }
        if let group = payload.group {
            queryItems.append(URLQueryItem(name: "group", value: group))
        }
        if let url = payload.targetURL {
            queryItems.append(URLQueryItem(name: "url", value: url))
        }
        if let level = barkLevel(from: payload.priority) {
            queryItems.append(URLQueryItem(name: "level", value: level))
        }
        if configuration.icon != nil {
            queryItems.append(URLQueryItem(name: "icon", value: configuration.icon))
        }
        if configuration.isArchive {
            queryItems.append(URLQueryItem(name: "isArchive", value: "1"))
        }
        if configuration.copyable {
            queryItems.append(URLQueryItem(name: "copyable", value: "1"))
        }
        
        var urlComponents = URLComponents(string: urlString)
        if !queryItems.isEmpty {
            urlComponents?.queryItems = queryItems
        }
        
        guard let url = urlComponents?.url else {
            throw MessageError.invalidPayload(reason: "Failed to build Bark URL")
        }
        
        return url
    }
    
    private func barkLevel(from priority: MessagePriority) -> String? {
        switch priority {
        case .critical:
            return "timeSensitive"
        case .high:
            return "active"
        case .normal:
            return nil  // Default
        case .low:
            return "passive"
        }
    }
}

/// Bark channel configuration
public struct BarkConfiguration: Sendable {
    public let icon: String?
    public let isArchive: Bool
    public let copyable: Bool
    public let maxRetries: Int
    public let timeout: TimeInterval
    
    public init(
        icon: String? = nil,
        isArchive: Bool = false,
        copyable: Bool = true,
        maxRetries: Int = 3,
        timeout: TimeInterval = 30
    ) {
        self.icon = icon
        self.isArchive = isArchive
        self.copyable = copyable
        self.maxRetries = maxRetries
        self.timeout = timeout
    }
    
    public static let `default` = BarkConfiguration()
}
