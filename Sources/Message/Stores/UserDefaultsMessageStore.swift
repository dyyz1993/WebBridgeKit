import Foundation

public actor UserDefaultsMessageStore: MessageStore {
    private let defaults: UserDefaults
    private let key: String
    private let maxMessages: Int

    public init(suiteName: String? = nil, key: String = "WebBridgeKit_Messages", maxMessages: Int = 200) {
        self.defaults = UserDefaults(suiteName: suiteName) ?? .standard
        self.key = key
        self.maxMessages = maxMessages
    }

    public func save(_ message: StoredMessage) async throws {
        var messages = loadAll()
        messages.insert(message, at: 0)
        if messages.count > maxMessages {
            messages = Array(messages.prefix(maxMessages))
        }
        saveAll(messages)
    }

    public func get(id: String) async -> StoredMessage? {
        loadAll().first { $0.id == id }
    }

    public func getAll() async -> [StoredMessage] {
        loadAll()
    }

    public func getByChannel(_ channel: String) async -> [StoredMessage] {
        loadAll().filter { $0.payload.channel == channel }
    }

    public func getUnread() async -> [StoredMessage] {
        loadAll().filter { !$0.isRead }
    }

    public func getUnreadCount() async -> Int {
        loadAll().filter { !$0.isRead }.count
    }

    public func markAsRead(id: String) async {
        var messages = loadAll()
        if let index = messages.firstIndex(where: { $0.id == id }) {
            messages[index].markRead()
            saveAll(messages)
        }
    }

    public func markAllAsRead() async {
        var messages = loadAll()
        for i in messages.indices {
            messages[i].markRead()
        }
        saveAll(messages)
    }

    public func delete(id: String) async {
        var messages = loadAll()
        messages.removeAll { $0.id == id }
        saveAll(messages)
    }

    public func deleteAll() async {
        defaults.removeObject(forKey: key)
    }

    public func count() async -> Int {
        loadAll().count
    }

    private func loadAll() -> [StoredMessage] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([StoredMessage].self, from: data)) ?? []
    }

    private func saveAll(_ messages: [StoredMessage]) {
        let data = try? JSONEncoder().encode(messages)
        defaults.set(data, forKey: key)
    }
}
