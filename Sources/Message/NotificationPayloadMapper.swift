import Foundation

/// Shared mapping from a push notification's userInfo into `MessagePayload`.
///
/// Both the live path (AppDelegate foreground/tap handling) and the replay
/// path (PendingMessageImporter reading Notification Service Extension
/// records) must produce identical payload ids — `messageId ?? id ?? request
/// identifier` — so MessageEngine's `findExistingMessage` dedups a banner
/// tap against the later import instead of storing the push twice.
public enum NotificationPayloadMapper {

    /// Values used when the userInfo lacks the field. The live path supplies
    /// them from `UNNotificationContent`; the replay path supplies them from
    /// the content snapshot persisted by the extension.
    public struct ContentFallbacks {
        public var title: String?
        public var body: String?
        public var subtitle: String?
        public var badge: Int?

        public init(title: String? = nil, body: String? = nil, subtitle: String? = nil, badge: Int? = nil) {
            self.title = title
            self.body = body
            self.subtitle = subtitle
            self.badge = badge
        }
    }

    public static func makePayload(
        identifier: String,
        userInfo: [AnyHashable: Any],
        fallbacks: ContentFallbacks = ContentFallbacks()
    ) -> MessagePayload {
        let aps = userInfo["aps"] as? [String: Any]
        let rawMarkdown = userInfo["markdown"] as? String
        let markdown = rawMarkdown == "1" || rawMarkdown?.lowercased() == "true"
            ? (userInfo["body"] as? String ?? fallbacks.body ?? "")
            : rawMarkdown
        let level = notificationLevel(
            userInfo["level"] as? String ?? aps?["interruption-level"] as? String
        )
        let requestID = userInfo["requestId"] as? String
        let replacementID = userInfo["id"] as? String
        let payloadID = (userInfo["messageId"] as? String) ?? replacementID ?? identifier

        var stringUserInfo = notificationStringDictionary(userInfo)
        if let params = userInfo["params"] as? [String: Any] {
            for (key, value) in params {
                if let string = notificationString(value) {
                    stringUserInfo[key] = string
                }
            }
        }

        return MessagePayload(
            id: payloadID,
            title: userInfo["title"] as? String ?? fallbacks.title ?? "",
            body: userInfo["body"] as? String ?? fallbacks.body ?? "",
            markdown: markdown,
            subtitle: userInfo["subtitle"] as? String ?? fallbacks.subtitle,
            channel: userInfo["channel"] as? String ?? "apns",
            category: userInfo["category"] as? String,
            priority: messagePriority(for: level),
            sound: userInfo["sound"] as? String,
            badge: notificationInt(userInfo["badge"]) ?? fallbacks.badge,
            group: userInfo["group"] as? String,
            threadId: (userInfo["threadId"] as? String)
                ?? (userInfo["thread-id"] as? String)
                ?? (aps?["thread-id"] as? String),
            targetURL: userInfo["url"] as? String,
            targetAppId: (userInfo["appId"] as? String) ?? (userInfo["appid"] as? String),
            route: userInfo["route"] as? String,
            targetMode: notificationTargetMode(userInfo),
            verificationCode: userInfo["verificationCode"] as? String,
            expiresAt: notificationExpiration(userInfo),
            imageURL: userInfo["image"] as? String,
            iconURL: userInfo["icon"] as? String,
            interruptionLevel: MessageInterruptionLevel(rawValue: level ?? ""),
            soundVolume: notificationDouble(userInfo["volume"]),
            isCall: notificationBool(userInfo["call"]),
            copyText: userInfo["copy"] as? String,
            isAutoCopy: notificationBool(userInfo["autoCopy"] ?? userInfo["automaticallyCopy"]),
            isArchive: notificationBool(userInfo["isArchive"]),
            ttl: notificationDouble(userInfo["ttl"]),
            replacementID: replacementID,
            isDeleted: notificationBool(userInfo["delete"]),
            actionState: MessageActionState(
                rawValue: ((userInfo["state"] as? String) ?? (userInfo["actionState"] as? String) ?? "").lowercased()
            ),
            requestID: requestID,
            contentType: MessageContentType(
                rawValue: ((userInfo["type"] as? String) ?? (userInfo["contentType"] as? String) ?? "").lowercased()
            ),
            qrPayload: userInfo["qrPayload"] as? String,
            statePath: userInfo["statePath"] as? String,
            revision: notificationInt(userInfo["revision"]),
            presentation: MessagePresentation(
                rawValue: (userInfo["presentation"] as? String ?? "").lowercased()
            ),
            approval: notificationApproval(userInfo["approval"]),
            userInfo: stringUserInfo
        )
    }

    private static func notificationApproval(_ value: Any?) -> MessageApproval? {
        guard let object = value as? [String: Any],
              let rawActions = object["actions"] as? [[String: Any]] else { return nil }
        let actions = rawActions.compactMap { action -> MessageApprovalAction? in
            guard let id = action["id"] as? String,
                  let title = action["title"] as? String,
                  !id.isEmpty,
                  !title.isEmpty else { return nil }
            return MessageApprovalAction(
                id: id,
                title: title,
                style: MessageApprovalActionStyle(rawValue: action["style"] as? String ?? ""),
                requiresReason: notificationBool(action["requiresReason"]),
                resultState: MessageActionState(rawValue: action["resultState"] as? String ?? "")
            )
        }
        return actions.isEmpty ? nil : MessageApproval(actions: actions)
    }

    private static func notificationStringDictionary(_ userInfo: [AnyHashable: Any]) -> [String: String] {
        userInfo.reduce(into: [:]) { result, item in
            guard let key = item.key as? String, let value = notificationString(item.value) else { return }
            result[key] = value
        }
    }

    private static func notificationString(_ value: Any?) -> String? {
        switch value {
        case let value as String:
            return value
        case let value as NSNumber:
            return value.stringValue
        default:
            return nil
        }
    }

    private static func notificationInt(_ value: Any?) -> Int? {
        switch value {
        case let value as Int:
            return value
        case let value as NSNumber:
            return value.intValue
        case let value as String:
            return Int(value)
        default:
            return nil
        }
    }

    private static func notificationDouble(_ value: Any?) -> Double? {
        switch value {
        case let value as Double:
            return value
        case let value as NSNumber:
            return value.doubleValue
        case let value as String:
            return Double(value)
        default:
            return nil
        }
    }

    private static func notificationTargetMode(_ userInfo: [AnyHashable: Any]) -> String? {
        if let mode = userInfo["mode"] as? String { return mode }
        switch userInfo["display"] as? String {
        case "sheet", "inline": return "modal"
        case "full": return "immersive"
        default: return nil
        }
    }

    private static func notificationLevel(_ value: String?) -> String? {
        switch value {
        case "time-sensitive", "timeSensitive": return "timeSensitive"
        case "passive", "active", "critical": return value
        default: return nil
        }
    }

    private static func notificationBool(_ value: Any?) -> Bool? {
        switch value {
        case let value as Bool:
            return value
        case let value as NSNumber:
            return value.boolValue
        case let value as String:
            return value == "1" || value.lowercased() == "true"
        default:
            return nil
        }
    }

    private static func notificationExpiration(_ userInfo: [AnyHashable: Any]) -> Date? {
        guard let rawValue = userInfo["expiresAt"] else { return nil }
        if let timestamp = rawValue as? TimeInterval {
            return Date(timeIntervalSince1970: timestamp)
        }
        if let timestamp = rawValue as? NSNumber {
            return Date(timeIntervalSince1970: timestamp.doubleValue)
        }
        if let value = rawValue as? String {
            return ISO8601DateFormatter().date(from: value)
        }
        return nil
    }

    private static func messagePriority(for level: String?) -> MessagePriority {
        switch MessageInterruptionLevel(rawValue: level ?? "") {
        case .critical:
            return .critical
        case .timeSensitive:
            return .high
        case .passive:
            return .low
        default:
            return .normal
        }
    }
}
