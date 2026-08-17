import UniformTypeIdentifiers
import UserNotifications

/// Records incoming push payloads to shared plist files so the main app can
/// import them into its message store on next foreground — mirroring Bark's
/// approach (the app itself may be suspended or killed when the push lands).
final class NotificationService: UNNotificationServiceExtension {

    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttempt: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        self.bestAttempt = (request.content.mutableCopy() as? UNMutableNotificationContent)

        recordPayload(request.content.userInfo)

        // Bark-style: pass the notification through unmodified. Rich media
        // and decryption can be added later without changing the recording
        // contract.
        contentHandler(request.content)
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler, let bestAttempt {
            contentHandler(bestAttempt)
        }
    }

    // MARK: - Shared-file recording (Bark pattern)

    private func recordPayload(_ userInfo: [AnyHashable: Any]) {
        guard let groupURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.webbridgekit.superapp")
        else { return }

        let pendingDir = groupURL.appendingPathComponent("pending_messages", isDirectory: true)
        try? FileManager.default.createDirectory(at: pendingDir, withIntermediateDirectories: true)

        let dict = NSMutableDictionary(dictionary: userInfo)
        dict["recordedAt"] = Date().timeIntervalSince1970

        let fileName = "msg-\(Int(Date().timeIntervalSince1970 * 1000))-\(UUID().uuidString.prefix(8)).plist"
        let fileURL = pendingDir.appendingPathComponent(fileName)

        // Atomic write; if it fails the message stays only in Notification
        // Center, which is acceptable degradation.
        dict.write(to: fileURL, atomically: true)
    }
}
