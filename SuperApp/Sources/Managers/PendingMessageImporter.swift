import Foundation
import WebBridgeKit

/// Two-tier background message recovery:
/// 1. NSE plist files (App Group) — instant, offline, written by NotificationServiceExtension
/// 2. Server message history API — fallback when NSE didn't fire (server restart, etc.)
enum PendingMessageImporter {

    private static let appGroupID = "group.com.webbridgekit.superapp"
    private static let lastSyncKey = "com.webbridgekit.lastMessageSync"

    static func importPending() async {
        await importFromAppGroup()
        await importFromServer()
    }

    // MARK: - Tier 1: NSE plist files (Bark pattern)

    private static func importFromAppGroup() async {
        guard let groupURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
        else { return }

        let pendingDir = groupURL.appendingPathComponent("pending_messages", isDirectory: true)
        guard FileManager.default.fileExists(atPath: pendingDir.path) else { return }

        let files = (try? FileManager.default.contentsOfDirectory(
            at: pendingDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ))?.filter { $0.pathExtension == "plist" } ?? []

        for fileURL in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard let dict = NSDictionary(contentsOf: fileURL) as? [String: Any] else {
                try? FileManager.default.removeItem(at: fileURL)
                continue
            }

            let payload = MessagePayload(
                title: dict["title"] as? String ?? "",
                body: dict["body"] as? String ?? "",
                channel: "apns"
            )
            try? await MessageEngine.shared.receive(payload)
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    // MARK: - Tier 2: Server message history (fallback)

    private static func importFromServer() async {
        guard let serverURL = serverBaseURL,
              let identity = try? OfficialPushIdentityStore.shared.currentOrCreate()
        else { return }

        let lastSync = UserDefaults.standard.double(forKey: lastSyncKey)
        let urlString = "\(serverURL)/api/v1/messages/\(identity)?since=\(Int(lastSync))"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }

            let history = try JSONDecoder().decode(MessageHistory.self, from: data)
            guard !history.messages.isEmpty else { return }

            var latest = lastSync
            for message in history.messages {
                let payload = MessagePayload(
                    title: message.title,
                    body: message.body,
                    channel: "apns"
                )
                try? await MessageEngine.shared.receive(payload)
                latest = max(latest, Double(message.timestamp))
            }

            if latest > lastSync {
                UserDefaults.standard.set(latest, forKey: lastSyncKey)
            }
        } catch {
            // Offline or server unreachable; NSE tier already covered local case
        }
    }

    private static var serverBaseURL: String? {
        ServerConfigManager.shared.getActiveBaseURL()
            ?? UserDefaults.standard.string(forKey: "com.webbridgekit.bark.server")
            ?? "https://wbk.shanbox.19930810.xyz:8443"
    }

    private struct MessageHistory: Codable {
        let messages: [Item]
        struct Item: Codable {
            let title: String
            let body: String
            let timestamp: Int
        }
    }
}
