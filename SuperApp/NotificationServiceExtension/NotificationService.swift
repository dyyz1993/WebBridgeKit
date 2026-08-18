import UserNotifications

/// Records incoming push payloads to shared plist files so the main app can
/// import them into its message store on next foreground — mirroring Bark's
/// Notification Service Extension approach.
final class NotificationService: UNNotificationServiceExtension {

    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttempt: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        self.bestAttempt = (request.content.mutableCopy() as? UNMutableNotificationContent)

        // Write the full payload to the App Group shared container so the
        // main app can import it even if the user never taps the notification.
        recordPayload(request.content.userInfo)

        // Pass through unmodified; rich processing (decrypt, images) can be
        // added later without changing the recording contract.
        contentHandler(request.content)
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler, let bestAttempt {
            contentHandler(bestAttempt)
        }
    }

    // MARK: - Shared-file recording (Bark pattern: ArchiveProcessor)

    private func recordPayload(_ userInfo: [AnyHashable: Any]) {
        guard let groupURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.webbridgekit.superapp")
        else { return }

        let pendingDir = groupURL.appendingPathComponent("pending_messages", isDirectory: true)
        try? FileManager.default.createDirectory(at: pendingDir, withIntermediateDirectories: true)

        // Extract display fields from the APNs payload (aps.alert + top-level)
        let aps = userInfo["aps"] as? [String: Any]
        let alert = aps?["alert"] as? [String: Any]
        let title = (userInfo["title"] as? String) ?? (alert?["title"] as? String) ?? ""
        let body = (userInfo["body"] as? String) ?? (alert?["body"] as? String) ?? ""

        var dict: [String: Any] = [
            "title": title,
            "body": body,
            "timestamp": Int(Date().timeIntervalSince1970),
        ]
        if let group = userInfo["group"] as? String { dict["group"] = group }
        if let url = userInfo["url"] as? String { dict["url"] = url }

        let fileName = "msg-\(Int(Date().timeIntervalSince1970 * 1000)).plist"
        let fileURL = pendingDir.appendingPathComponent(fileName)

        NSDictionary(dictionary: dict).write(to: fileURL, atomically: true)
    }
}
