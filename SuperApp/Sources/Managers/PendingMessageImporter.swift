import Foundation
import UserNotifications
import WebBridgeKit

/// Reads push payloads recorded by the Notification Service Extension from
/// the shared App Group directory and imports them into the MessageEngine.
/// Called on app launch and on `applicationDidBecomeActive` so background
/// pushes are never lost from the Inbox.
enum PendingMessageImporter {

    private static let appGroupID = "group.com.xuyingzhou.bark"

    static func importPending() async {
        guard let groupURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
        else { return }

        let pendingDir = groupURL.appendingPathComponent("pending_messages", isDirectory: true)
        guard FileManager.default.fileExists(atPath: pendingDir.path) else { return }

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: pendingDir,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let plists = files
            .filter { $0.pathExtension == "plist" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        guard !plists.isEmpty else { return }

        for fileURL in plists {
            guard let dict = NSDictionary(contentsOf: fileURL) as? [String: Any] else {
                try? FileManager.default.removeItem(at: fileURL)
                continue
            }

            let userInfo = dict
            let title = userInfo["title"] as? String ?? ""
            let body = userInfo["body"] as? String ?? ""

            let payload = MessagePayload(
                title: title,
                body: body,
                channel: userInfo["channel"] as? String ?? "apns"
            )

            try? await MessageEngine.shared.receive(payload)

            try? FileManager.default.removeItem(at: fileURL)
        }
    }
}
