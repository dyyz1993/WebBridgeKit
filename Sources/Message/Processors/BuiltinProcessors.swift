import Foundation
import UIKit
import UserNotifications

// MARK: - Processor Pipeline

/// Ordered pipeline of message processors (inspired by Bark)
public actor MessageProcessorPipeline {
    private var processors: [any MessageProcessor] = []
    
    public init() {}
    
    /// Register a processor
    public func register(_ processor: any MessageProcessor) {
        processors.append(processor)
        processors.sort { $0.priority < $1.priority }
    }
    
    /// Process content through all enabled processors
    public func process(content: MutableMessageContent) async throws -> MutableMessageContent {
        var current = content
        for processor in processors where processor.isEnabled {
            current = try await processor.process(content: current)
        }
        return current
    }
    
    /// List all registered processors
    public func listProcessors() -> [(id: String, priority: Int, enabled: Bool)] {
        processors.map { (id: $0.identifier, priority: $0.priority, enabled: $0.isEnabled) }
    }
}

// MARK: - Built-in Processors

/// 1. Markdown Processor - converts markdown body to plain text for notifications
public struct MarkdownProcessor: MessageProcessor {
    public let identifier = "markdown"
    public let priority = 100
    public var isEnabled = true
    
    public init() {}
    
    public func process(content: MutableMessageContent) async throws -> MutableMessageContent {
        var content = content
        if content.bodyType == .markdown {
            content.body = stripMarkdown(content.body)
        }
        return content
    }
    
    private func stripMarkdown(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "\\*\\*(.+?)\\*\\*", with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: "\\*(.+?)\\*", with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: "`(.+?)`", with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: "\\[(.+?)\\]\\(.+?\\)", with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: "^#{1,6}\\s+", with: "", options: .regularExpression)
        return result
    }
}

/// 2. Level Processor - sets interruption level
public struct LevelProcessor: MessageProcessor {
    public let identifier = "level"
    public let priority = 200
    public var isEnabled = true
    
    public init() {}
    
    public func process(content: MutableMessageContent) async throws -> MutableMessageContent {
        return content
    }
}

/// 3. Badge Processor - manages badge number
public struct BadgeProcessor: MessageProcessor {
    public let identifier = "badge"
    public let priority = 300
    public var isEnabled = true
    
    private let badgeManager: BadgeManageable
    
    public init(badgeManager: BadgeManageable = DefaultBadgeManager()) {
        self.badgeManager = badgeManager
    }
    
    public func process(content: MutableMessageContent) async throws -> MutableMessageContent {
        if let badge = content.badge {
            await badgeManager.setBadge(badge)
        }
        return content
    }
}

/// 4. Auto Copy Processor - copies content to clipboard
public struct AutoCopyProcessor: MessageProcessor {
    public let identifier = "autoCopy"
    public let priority = 400
    public var isEnabled = true
    
    public init() {}
    
    public func process(content: MutableMessageContent) async throws -> MutableMessageContent {
        if content.isAutoCopy {
            let textToCopy = content.copyText ?? content.body
            await MainActor.run {
                UIPasteboard.general.string = textToCopy
            }
        }
        return content
    }
}

/// 5. Archive Processor - archives message to persistent store
public struct ArchiveProcessor: MessageProcessor {
    public let identifier = "archive"
    public let priority = 500
    public var isEnabled = true
    
    private let store: any MessageStore
    
    public init(store: any MessageStore) {
        self.store = store
    }
    
    public func process(content: MutableMessageContent) async throws -> MutableMessageContent {
        guard content.isArchive else { return content }
        
        let payload = MessagePayload(
            title: content.title,
            body: content.body,
            subtitle: content.subtitle,
            channel: "push",
            group: content.group,
            threadId: content.threadId,
            targetURL: content.targetURL,
            targetAppId: content.targetAppId,
            targetMode: content.targetMode,
            userInfo: content.userInfo as? [String: String]
        )
        
        let message = StoredMessage(payload: payload)
        try await store.save(message)
        
        return content
    }
}

/// 6. Mute Processor - checks group mute settings
public struct MuteProcessor: MessageProcessor {
    public let identifier = "mute"
    public let priority = 600
    public var isEnabled = true
    
    private var mutedGroups: Set<String> = []
    
    public init() {}
    
    public func process(content: MutableMessageContent) async throws -> MutableMessageContent {
        var content = content
        if let group = content.group, mutedGroups.contains(group) {
            content.level = .passive
        }
        return content
    }
    
    public mutating func muteGroup(_ group: String) {
        mutedGroups.insert(group)
    }
    
    public mutating func unmuteGroup(_ group: String) {
        mutedGroups.remove(group)
    }
}

// MARK: - Supporting Protocols

public protocol BadgeManageable: Sendable {
    func setBadge(_ count: Int) async
}

public struct DefaultBadgeManager: BadgeManageable {
    public init() {}
    
    public func setBadge(_ count: Int) async {
        await MainActor.run {
            if #available(iOS 16.0, *) {
                UNUserNotificationCenter.current().setBadgeCount(count) { _ in }
            } else {
                UIApplication.shared.applicationIconBadgeNumber = count
            }
        }
    }
}
