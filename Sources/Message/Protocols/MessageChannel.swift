import Foundation

/// Message channel protocol - defines how messages are received
public protocol MessageChannel: AnyObject, Sendable {
    /// Channel identifier
    var channelId: String { get }

    /// Whether the channel is active
    var isActive: Bool { get }

    /// Start listening for messages
    func start() async

    /// Stop listening for messages
    func stop() async

    /// Send a message through this channel
    func send(_ payload: MessagePayload) async throws -> MessageSendResult
}

/// Message payload - unified message format
public struct MessagePayload: Codable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let body: String
    public let markdown: String?
    public let subtitle: String?
    public let channel: String
    public let category: String?
    public let priority: MessagePriority
    public let sound: String?
    public let badge: Int?
    public let group: String?
    public let threadId: String?
    public let targetURL: String?
    public let targetAppId: String?
    public let targetMode: String?
    public let userInfo: [String: String]?
    public let createdAt: Date

    public init(
        id: String = UUID().uuidString,
        title: String,
        body: String,
        markdown: String? = nil,
        subtitle: String? = nil,
        channel: String,
        category: String? = nil,
        priority: MessagePriority = .normal,
        sound: String? = nil,
        badge: Int? = nil,
        group: String? = nil,
        threadId: String? = nil,
        targetURL: String? = nil,
        targetAppId: String? = nil,
        targetMode: String? = nil,
        userInfo: [String: String]? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.markdown = markdown
        self.subtitle = subtitle
        self.channel = channel
        self.category = category
        self.priority = priority
        self.sound = sound
        self.badge = badge
        self.group = group
        self.threadId = threadId
        self.targetURL = targetURL
        self.targetAppId = targetAppId
        self.targetMode = targetMode
        self.userInfo = userInfo
        self.createdAt = createdAt
    }

    /// Whether this message has a routing target
    public var hasRoute: Bool {
        targetURL != nil || targetAppId != nil
    }
}

/// Message priority levels
public enum MessagePriority: String, Codable, Sendable, CaseIterable {
    case low
    case normal
    case high
    case critical

    public var intValue: Int {
        switch self {
        case .low: return 0
        case .normal: return 5
        case .high: return 8
        case .critical: return 10
        }
    }
}

/// Message send result
public enum MessageSendResult: Sendable {
    case success(messageId: String)
    case failed(error: MessageError)
    case queued(messageId: String)
}

/// Message errors
public enum MessageError: Error, Sendable, LocalizedError {
    case channelNotActive(channelId: String)
    case channelNotConfigured(channelId: String)
    case invalidPayload(reason: String)
    case sendFailed(reason: String)
    case networkError(underlying: Error)
    case unauthorized
    case rateLimited(retryAfter: TimeInterval?)
    case serverError(statusCode: Int, message: String)

    public var errorDescription: String? {
        switch self {
        case .channelNotActive(let id):
            return "Channel '\(id)' is not active"
        case .channelNotConfigured(let id):
            return "Channel '\(id)' is not configured"
        case .invalidPayload(let reason):
            return "Invalid payload: \(reason)"
        case .sendFailed(let reason):
            return "Send failed: \(reason)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unauthorized:
            return "Unauthorized - check API key"
        case .rateLimited(let retryAfter):
            if let retryAfter = retryAfter {
                return "Rate limited - retry after \(retryAfter) seconds"
            }
            return "Rate limited"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        }
    }
}
