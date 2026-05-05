import UserNotifications
import WebBridgeKit

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    private lazy var pipeline: NotificationProcessorPipeline = {
        let pipeline = NotificationProcessorPipeline()
        pipeline.register(TitleProcessor())
        pipeline.register(BodyProcessor())
        pipeline.register(SoundProcessor())
        pipeline.register(BadgeProcessor())
        pipeline.register(GroupProcessor())
        pipeline.register(ThreadProcessor())
        pipeline.register(ImageProcessor())
        pipeline.register(MarkdownNotificationProcessor())
        return pipeline
    }()

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        guard let content = bestAttemptContent else { return }

        Task {
            do {
                let processed = try await pipeline.process(content: content, userInfo: request.content.userInfo)
                contentHandler(processed)
            } catch {
                contentHandler(content)
            }
        }
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
}

struct NotificationProcessorPipeline {
    private var processors: [any NotificationContentProcessor] = []

    mutating func register(_ processor: any NotificationContentProcessor) {
        processors.append(processor)
    }

    func process(
        content: UNMutableNotificationContent,
        userInfo: [AnyHashable: Any]
    ) async throws -> UNNotificationContent {
        var current = content
        for processor in processors {
            current = try await processor.process(content: current, userInfo: userInfo)
        }
        return current
    }
}

protocol NotificationContentProcessor {
    func process(
        content: UNMutableNotificationContent,
        userInfo: [AnyHashable: Any]
    ) async throws -> UNMutableNotificationContent
}

struct TitleProcessor: NotificationContentProcessor {
    func process(content: UNMutableNotificationContent, userInfo: [AnyHashable: Any]) async throws -> UNMutableNotificationContent {
        if let title = userInfo["title"] as? String, !title.isEmpty {
            content.title = title
        }
        if let subtitle = userInfo["subtitle"] as? String, !subtitle.isEmpty {
            content.subtitle = subtitle
        }
        return content
    }
}

struct BodyProcessor: NotificationContentProcessor {
    func process(content: UNMutableNotificationContent, userInfo: [AnyHashable: Any]) async throws -> UNMutableNotificationContent {
        if let body = userInfo["body"] as? String, !body.isEmpty {
            content.body = body
        }
        return content
    }
}

struct SoundProcessor: NotificationContentProcessor {
    func process(content: UNMutableNotificationContent, userInfo: [AnyHashable: Any]) async throws -> UNMutableNotificationContent {
        if let soundName = userInfo["sound"] as? String, !soundName.isEmpty {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(soundName))
        }
        return content
    }
}

struct BadgeProcessor: NotificationContentProcessor {
    func process(content: UNMutableNotificationContent, userInfo: [AnyHashable: Any]) async throws -> UNMutableNotificationContent {
        if let badge = userInfo["badge"] as? Int {
            content.badge = badge as NSNumber
        }
        return content
    }
}

struct GroupProcessor: NotificationContentProcessor {
    func process(content: UNMutableNotificationContent, userInfo: [AnyHashable: Any]) async throws -> UNMutableNotificationContent {
        if let group = userInfo["group"] as? String, !group.isEmpty {
            content.threadIdentifier = group
            content.categoryIdentifier = group
        }
        return content
    }
}

struct ThreadProcessor: NotificationContentProcessor {
    func process(content: UNMutableNotificationContent, userInfo: [AnyHashable: Any]) async throws -> UNMutableNotificationContent {
        if let threadId = userInfo["thread-id"] as? String, !threadId.isEmpty {
            content.threadIdentifier = threadId
        }
        return content
    }
}

struct ImageProcessor: NotificationContentProcessor {
    func process(content: UNMutableNotificationContent, userInfo: [AnyHashable: Any]) async throws -> UNMutableNotificationContent {
        guard let imageURLString = userInfo["image"] as? String,
              let imageURL = URL(string: imageURLString) else {
            return content
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: imageURL)
            let tempDir = NSTemporaryDirectory()
            let fileName = imageURL.lastPathComponent
            let tempFile = URL(fileURLWithPath: tempDir).appendingPathComponent(fileName)
            try data.write(to: tempFile)

            if let attachment = try? UNNotificationAttachment(
                identifier: "image",
                url: tempFile,
                options: [UNNotificationAttachmentOptionsTypeHintKey: "public.image"]
            ) {
                content.attachments = [attachment]
            }
        } catch {
        }

        return content
    }
}

struct MarkdownNotificationProcessor: NotificationContentProcessor {
    func process(content: UNMutableNotificationContent, userInfo: [AnyHashable: Any]) async throws -> UNMutableNotificationContent {
        guard (userInfo["markdown"] as? String) == "1" else { return content }

        var body = content.body
        body = body.replacingOccurrences(of: "\\*\\*(.+?)\\*\\*", with: "$1", options: .regularExpression)
        body = body.replacingOccurrences(of: "\\*(.+?)\\*", with: "$1", options: .regularExpression)
        body = body.replacingOccurrences(of: "`(.+?)`", with: "$1", options: .regularExpression)
        body = body.replacingOccurrences(of: "\\[(.+?)\\]\\(.+?\\)", with: "$1", options: .regularExpression)
        body = body.replacingOccurrences(of: "^#{1,6}\\s+", with: "", options: .regularExpression)

        content.body = body
        return content
    }
}
