import Foundation

/// Message persistence protocol
public protocol MessageStore: AnyObject, Sendable {
    /// Save a message
    func save(_ message: StoredMessage) async throws

    /// Get message by ID
    func get(id: String) async -> StoredMessage?

    /// Get all messages
    func getAll() async -> [StoredMessage]

    /// Get messages by channel
    func getByChannel(_ channel: String) async -> [StoredMessage]

    /// Get unread messages
    func getUnread() async -> [StoredMessage]

    /// Get unread count
    func getUnreadCount() async -> Int

    /// Mark message as read
    func markAsRead(id: String) async

    /// Mark all messages as read
    func markAllAsRead() async

    /// Delete message by ID
    func delete(id: String) async

    /// Delete all messages
    func deleteAll() async

    /// Get message count
    func count() async -> Int
}

/// Stored message with read state
public struct StoredMessage: Codable, Sendable, Identifiable {
    public let id: String
    public let payload: MessagePayload
    public var isRead: Bool
    public var readAt: Date?
    public var receivedAt: Date
    public var bodyType: String

    public init(
        id: String = UUID().uuidString,
        payload: MessagePayload,
        isRead: Bool = false,
        readAt: Date? = nil,
        receivedAt: Date = Date(),
        bodyType: String = "plainText"
    ) {
        self.id = id
        self.payload = payload
        self.isRead = isRead
        self.readAt = readAt
        self.receivedAt = receivedAt
        self.bodyType = bodyType
    }

    /// Mark as read
    public mutating func markRead() {
        isRead = true
        readAt = Date()
    }
}
