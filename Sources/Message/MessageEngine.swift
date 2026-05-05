import Foundation

/// Central message engine that coordinates channels, routing, and persistence
public actor MessageEngine {
    /// Shared singleton
    public static let shared = MessageEngine()
    
    private var channels: [String: any MessageChannel] = [:]
    private var store: any MessageStore
    private var router: MessageRouter
    private var handlers: [String: MessageHandler] = [:]
    private var statistics: MessageStatistics
    
    /// Message received callback
    public var onMessageReceived: (@Sendable (StoredMessage) -> Void)?
    
    /// Route callback
    public var onRoute: (@Sendable (MessagePayload, RouteTarget) -> Void)?
    
    private init() {
        self.store = InMemoryMessageStore()
        self.router = MessageRouter()
        self.statistics = MessageStatistics()
    }
    
    // MARK: - Channel Management
    
    /// Register a message channel
    public func registerChannel(_ channel: any MessageChannel) {
        channels[channel.channelId] = channel
    }
    
    /// Unregister a channel
    public func unregisterChannel(_ channelId: String) {
        channels.removeValue(forKey: channelId)
    }
    
    /// Get all registered channels
    public func getRegisteredChannels() -> [String] {
        Array(channels.keys)
    }
    
    // MARK: - Store Management
    
    /// Set custom message store
    public func setStore(_ store: any MessageStore) {
        self.store = store
    }
    
    // MARK: - Handler Management
    
    /// Register a message handler for specific categories
    public func registerHandler(_ handler: MessageHandler, forCategory category: String) {
        handlers[category] = handler
    }
    
    // MARK: - Core Operations
    
    /// Start all registered channels
    public func startAll() async {
        for (_, channel) in channels {
            await channel.start()
        }
    }
    
    /// Stop all registered channels
    public func stopAll() async {
        for (_, channel) in channels {
            await channel.stop()
        }
    }
    
    /// Send a message through specified channel
    public func send(_ payload: MessagePayload, through channelId: String) async throws -> MessageSendResult {
        guard let channel = channels[channelId] else {
            throw MessageError.channelNotConfigured(channelId: channelId)
        }
        
        guard channel.isActive else {
            throw MessageError.channelNotActive(channelId: channelId)
        }
        
        let result = try await channel.send(payload)
        
        switch result {
        case .success(let messageId):
            statistics.recordSent(channelId: channelId)
        case .failed:
            statistics.recordFailed(channelId: channelId)
        case .queued(let messageId):
            statistics.recordQueued(channelId: channelId)
        }
        
        return result
    }
    
    /// Receive and process an incoming message
    public func receive(_ payload: MessagePayload) async throws {
        // Store the message
        let storedMessage = StoredMessage(payload: payload)
        try await store.save(storedMessage)
        
        statistics.recordReceived(channelId: payload.channel)
        
        // Notify handlers
        if let category = payload.category,
           let handler = handlers[category] {
            handler.handle(storedMessage)
        }
        
        // Route if applicable
        if payload.hasRoute {
            let target = router.route(payload: payload)
            onRoute?(payload, target)
        }
        
        // Notify callback
        onMessageReceived?(storedMessage)
    }
    
    // MARK: - Query Operations
    
    /// Get all stored messages
    public func getMessages() async -> [StoredMessage] {
        await store.getAll()
    }
    
    /// Get unread messages
    public func getUnreadMessages() async -> [StoredMessage] {
        await store.getUnread()
    }
    
    /// Get unread count
    public func getUnreadCount() async -> Int {
        await store.getUnreadCount()
    }
    
    /// Mark message as read
    public func markAsRead(id: String) async {
        await store.markAsRead(id: id)
    }
    
    /// Delete a message
    public func deleteMessage(id: String) async {
        await store.delete(id: id)
    }
    
    /// Clear all messages
    public func clearAllMessages() async {
        await store.deleteAll()
        statistics.reset()
    }
    
    // MARK: - Statistics
    
    /// Get engine statistics
    public func getStatistics() -> MessageStatistics {
        statistics
    }
}

// MARK: - Supporting Types

/// Message routing target
public struct RouteTarget: Sendable {
    public let type: RouteType
    public let destination: String
    public let mode: String?
    public let params: [String: String]?
    
    public init(type: RouteType, destination: String, mode: String? = nil, params: [String: String]? = nil) {
        self.type = type
        self.destination = destination
        self.mode = mode
        self.params = params
    }
}

/// Route type
public enum RouteType: String, Sendable {
    case url        // Open URL in browser
    case appId      // Open mini app
    case deeplink   // Deep link
    case none       // No routing
}

/// Message handler protocol
public protocol MessageHandler: AnyObject, Sendable {
    func handle(_ message: StoredMessage)
}

/// Message statistics
public struct MessageStatistics: Codable, Sendable {
    public var totalReceived: UInt64
    public var totalSent: UInt64
    public var totalFailed: UInt64
    public var totalQueued: UInt64
    public var byChannel: [String: ChannelStats]
    public var lastUpdated: Date
    
    public init() {
        self.totalReceived = 0
        self.totalSent = 0
        self.totalFailed = 0
        self.totalQueued = 0
        self.byChannel = [:]
        self.lastUpdated = Date()
    }
    
    public mutating func recordReceived(channelId: String) {
        totalReceived += 1
        byChannel[channelId, default: ChannelStats()].received += 1
        lastUpdated = Date()
    }
    
    public mutating func recordSent(channelId: String) {
        totalSent += 1
        byChannel[channelId, default: ChannelStats()].sent += 1
        lastUpdated = Date()
    }
    
    public mutating func recordFailed(channelId: String) {
        totalFailed += 1
        byChannel[channelId, default: ChannelStats()].failed += 1
        lastUpdated = Date()
    }
    
    public mutating func recordQueued(channelId: String) {
        totalQueued += 1
        byChannel[channelId, default: ChannelStats()].queued += 1
        lastUpdated = Date()
    }
    
    public mutating func reset() {
        totalReceived = 0
        totalSent = 0
        totalFailed = 0
        totalQueued = 0
        byChannel = [:]
        lastUpdated = Date()
    }
}

/// Channel-level statistics
public struct ChannelStats: Codable, Sendable {
    public var received: UInt64
    public var sent: UInt64
    public var failed: UInt64
    public var queued: UInt64
    
    public init(received: UInt64 = 0, sent: UInt64 = 0, failed: UInt64 = 0, queued: UInt64 = 0) {
        self.received = received
        self.sent = sent
        self.failed = failed
        self.queued = queued
    }
}

// MARK: - InMemoryMessageStore (default implementation)

/// Default in-memory message store
actor InMemoryMessageStore: MessageStore {
    private var messages: [String: StoredMessage] = [:]
    
    public func save(_ message: StoredMessage) async throws {
        messages[message.id] = message
    }
    
    public func get(id: String) async -> StoredMessage? {
        messages[id]
    }
    
    public func getAll() async -> [StoredMessage] {
        messages.values.sorted { $0.receivedAt > $1.receivedAt }
    }
    
    public func getByChannel(_ channel: String) async -> [StoredMessage] {
        messages.values
            .filter { $0.payload.channel == channel }
            .sorted { $0.receivedAt > $1.receivedAt }
    }
    
    public func getUnread() async -> [StoredMessage] {
        messages.values
            .filter { !$0.isRead }
            .sorted { $0.receivedAt > $1.receivedAt }
    }
    
    public func getUnreadCount() async -> Int {
        messages.values.filter { !$0.isRead }.count
    }
    
    public func markAsRead(id: String) async {
        messages[id]?.markRead()
    }
    
    public func markAllAsRead() async {
        for id in messages.keys {
            messages[id]?.markRead()
        }
    }
    
    public func delete(id: String) async {
        messages.removeValue(forKey: id)
    }
    
    public func deleteAll() async {
        messages.removeAll()
    }
    
    public func count() async -> Int {
        messages.count
    }
}
