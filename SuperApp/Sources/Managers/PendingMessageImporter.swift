import Foundation
import WebBridgeKit

/// Fetches messages that arrived while the app was backgrounded or killed.
/// Queries the server's per-device message history API instead of relying
/// on App Groups + Notification Service Extension.
enum PendingMessageImporter {

    private static let lastSyncKey = "com.webbridgekit.lastMessageSync"

    static func importPending() async {
        guard let serverURL = Self.serverBaseURL,
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
            // Network errors are expected; retry on next foreground
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
