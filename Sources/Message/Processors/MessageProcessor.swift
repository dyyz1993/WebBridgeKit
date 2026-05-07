import Foundation
import UserNotifications

/// Message processing protocol - inspired by Bark's NotificationContentProcessor
/// Each processor transforms a message in an ordered pipeline
public protocol MessageProcessor: Sendable {
    /// Unique processor identifier
    var identifier: String { get }
    
    /// Process priority (lower = earlier in pipeline)
    var priority: Int { get }
    
    /// Whether this processor is enabled
    var isEnabled: Bool { get }
    
    /// Process the message content
    /// - Parameter content: Mutable notification content to transform
    /// - Returns: Transformed content
    func process(content: MutableMessageContent) async throws -> MutableMessageContent
}

/// Mutable message content passed through the processor pipeline
public struct MutableMessageContent: @unchecked Sendable {
    public var title: String
    public var subtitle: String?
    public var body: String
    public var bodyType: MessageBodyType
    public var sound: String?
    public var badge: Int?
    public var group: String?
    public var threadId: String?
    public var targetURL: String?
    public var targetAppId: String?
    public var targetMode: String?
    public var imageURL: String?
    public var iconURL: String?
    public var level: MessageInterruptionLevel
    public var isAutoCopy: Bool
    public var copyText: String?
    public var isArchive: Bool
    public var isCall: Bool
    public var volume: Double?
    public var userInfo: [String: Any]
    public var ciphertext: String?
    public var cryptoAlgorithm: String?
    public var cryptoKey: String?
    public var cryptoIV: String?
    public var cryptoMode: String?
    
    public init(
        title: String = "",
        subtitle: String? = nil,
        body: String = "",
        bodyType: MessageBodyType = .plainText,
        sound: String? = nil,
        badge: Int? = nil,
        group: String? = nil,
        threadId: String? = nil,
        targetURL: String? = nil,
        targetAppId: String? = nil,
        targetMode: String? = nil,
        imageURL: String? = nil,
        iconURL: String? = nil,
        level: MessageInterruptionLevel = .active,
        isAutoCopy: Bool = false,
        copyText: String? = nil,
        isArchive: Bool = true,
        isCall: Bool = false,
        volume: Double? = nil,
        userInfo: [String: Any] = [:],
        ciphertext: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.bodyType = bodyType
        self.sound = sound
        self.badge = badge
        self.group = group
        self.threadId = threadId
        self.targetURL = targetURL
        self.targetAppId = targetAppId
        self.targetMode = targetMode
        self.imageURL = imageURL
        self.iconURL = iconURL
        self.level = level
        self.isAutoCopy = isAutoCopy
        self.copyText = copyText
        self.isArchive = isArchive
        self.isCall = isCall
        self.volume = volume
        self.userInfo = userInfo
        self.ciphertext = ciphertext
    }
    
    /// Create from APNs userInfo dictionary
    public init(userInfo: [AnyHashable: Any]) {
        self.userInfo = (userInfo as? [String: Any]) ?? [:]
        self.title = userInfo["title"] as? String ?? ""
        self.subtitle = userInfo["subtitle"] as? String
        self.body = userInfo["body"] as? String ?? ""
        self.sound = userInfo["sound"] as? String
        self.badge = userInfo["badge"] as? Int
        self.group = userInfo["group"] as? String
        self.threadId = userInfo["thread-id"] as? String
        self.targetURL = userInfo["url"] as? String
        self.targetAppId = userInfo["appid"] as? String ?? userInfo["appId"] as? String
        self.targetMode = userInfo["mode"] as? String
        self.imageURL = userInfo["image"] as? String
        self.iconURL = userInfo["icon"] as? String
        self.isAutoCopy = (userInfo["automaticallyCopy"] as? String) == "1" || (userInfo["autoCopy"] as? String) == "1"
        self.copyText = userInfo["copy"] as? String
        self.isArchive = (userInfo["isArchive"] as? String) == "1"
        self.isCall = (userInfo["call"] as? String) == "1"
        self.volume = userInfo["volume"] as? Double
        
        if let levelString = userInfo["level"] as? String {
            self.level = MessageInterruptionLevel(rawValue: levelString) ?? .active
        } else {
            self.level = .active
        }
        
        if let bodyTypeStr = userInfo["bodyType"] as? String {
            self.bodyType = MessageBodyType(rawValue: bodyTypeStr) ?? .plainText
        } else if (userInfo["markdown"] as? String) == "1" {
            self.bodyType = .markdown
        } else {
            self.bodyType = .plainText
        }
        
        self.ciphertext = userInfo["ciphertext"] as? String
        self.cryptoAlgorithm = userInfo["algorithm"] as? String
    }
}

/// Message body type
public enum MessageBodyType: String, Sendable, Codable {
    case plainText
    case markdown
}

/// Message interruption level (maps to UNNotificationInterruptionLevel)
public enum MessageInterruptionLevel: String, Sendable, Codable {
    case passive
    case active
    case timeSensitive
    case critical
    
    public var displayName: String {
        switch self {
        case .passive: return "静默"
        case .active: return "默认"
        case .timeSensitive: return "时效性"
        case .critical: return "紧急"
        }
    }
}
