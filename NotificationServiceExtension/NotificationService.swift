import UserNotifications
import AVFoundation

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    private let pipeline: NotificationProcessorPipeline = {
        var pipeline = NotificationProcessorPipeline()
        pipeline.register(TitleProcessor())
        pipeline.register(BodyProcessor())
        pipeline.register(SoundProcessor())
        pipeline.register(BadgeProcessor())
        pipeline.register(GroupProcessor())
        pipeline.register(ThreadProcessor())
        pipeline.register(ImageProcessor())
        pipeline.register(MarkdownNotificationProcessor())
        pipeline.register(IconProcessor())
        pipeline.register(CallProcessor())
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


// MARK: - Icon (banner attachment)

/// Downloads the icon URL and attaches it so the banner renders the custom
/// icon (modeled on Bark's IconProcessor).
struct IconProcessor: NotificationContentProcessor {
    func process(content: UNMutableNotificationContent, userInfo: [AnyHashable: Any]) async throws -> UNMutableNotificationContent {
        guard let iconURLString = userInfo["icon"] as? String,
              !iconURLString.isEmpty,
              let iconURL = URL(string: iconURLString) else {
            return content
        }
        // The URL's last path component carries the extension; fall back to png.
        let fileName = iconURL.lastPathComponent.isEmpty ? "icon.png" : iconURL.lastPathComponent
        let localURL = FileManager.default.temporaryDirectory.appendingPathComponent("nse-icon-\(fileName)")
        do {
            let (data, _) = try await URLSession.shared.data(from: iconURL)
            try data.write(to: localURL)
            let attachment = try UNNotificationAttachment(
                identifier: "icon",
                url: localURL,
                options: nil
            )
            content.attachments = content.attachments + [attachment]
        } catch {
            // Icon is decorative; a failed download must not break delivery.
        }
        return content
    }
}

// MARK: - Call (30-second continuous ring)

/// Extends the chosen ringtone to a 30-second loop for `call=1`, the way a
/// phone call keeps ringing (ported from Bark's CallProcessor): the source
/// sound is repeated via PCM buffers into `wbk.call.30s.<name>.caf` inside
/// the shared app group's Library/Sounds, then re-assigned as the content
/// sound so the system keeps playing it.
struct CallProcessor: NotificationContentProcessor {
    private static let longSoundPrefix = "wbk.call.30s"

    private var soundsDirectory: URL? {
        // App Group not yet provisioned; call=1 degrades to the normal
        // short tone until group.com.webbridgekit.superapp is registered.
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.webbridgekit.superapp"
        )?
        .appendingPathComponent("Library", isDirectory: true)
        .appendingPathComponent("Sounds", isDirectory: true)
    }

    func process(content: UNMutableNotificationContent, userInfo: [AnyHashable: Any]) async throws -> UNMutableNotificationContent {
        guard userInfo["call"] as? String == "1" || userInfo["call"] as? Int == 1 else {
            return content
        }
        // Sound arrives as "<name>.caf" from our URL generators.
        let rawName = (userInfo["sound"] as? String) ?? "alarm.caf"
        let baseName = (rawName as NSString).deletingPathExtension

        guard let longSound = extendToThirtySeconds(soundName: baseName) else {
            return content
        }
        content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: longSound.lastPathComponent))
        return content
    }

    private func extendToThirtySeconds(soundName: String) -> URL? {
        guard let soundsDirectory else { return nil }
        try? FileManager.default.createDirectory(at: soundsDirectory, withIntermediateDirectories: true)

        let longURL = soundsDirectory.appendingPathComponent("\(Self.longSoundPrefix).\(soundName).caf")
        if FileManager.default.fileExists(atPath: longURL.path) {
            return longURL
        }
        let sourceURL = soundsDirectory.appendingPathComponent("\(soundName).caf")
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            return nil
        }

        do {
            let audioFile = try AVAudioFile(forReading: sourceURL)
            let format = audioFile.processingFormat
            let targetFrames = AVAudioFramePosition(30 * format.sampleRate)
            let output = try AVAudioFile(forWriting: longURL, settings: format.settings)

            var written: AVAudioFramePosition = 0
            while written < targetFrames {
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(audioFile.length)) else {
                    return nil
                }
                try audioFile.read(into: buffer)
                let remaining = targetFrames - written
                if AVAudioFramePosition(buffer.frameLength) > remaining {
                    let truncated = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(remaining))!
                    for channel in 0..<Int(format.channelCount) {
                        memcpy(
                            truncated.floatChannelData![channel],
                            buffer.floatChannelData![channel],
                            Int(remaining) * MemoryLayout<Float>.size
                        )
                    }
                    truncated.frameLength = AVAudioFrameCount(remaining)
                    try output.write(from: truncated)
                    break
                }
                try output.write(from: buffer)
                written += AVAudioFramePosition(buffer.frameLength)
                audioFile.framePosition = 0
            }
            return longURL
        } catch {
            try? FileManager.default.removeItem(at: longURL)
            return nil
        }
    }
}
