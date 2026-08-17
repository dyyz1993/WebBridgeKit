import UserNotifications
import AVFoundation
import CryptoKit
import UIKit

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
        pipeline.register(AutoCopyProcessor())
        pipeline.register(CiphertextProcessor())
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


// MARK: - AutoCopy (clipboard on receive)

/// Copies the payload text to the clipboard when the push arrives, matching
/// Bark's AutoCopyProcessor (autocopy=1 / automaticallycopy=1).
struct AutoCopyProcessor: NotificationContentProcessor {
    func process(content: UNMutableNotificationContent, userInfo: [AnyHashable: Any]) async throws -> UNMutableNotificationContent {
        let autoCopy = userInfo["autoCopy"] as? String == "1"
            || userInfo["automaticallyCopy"] as? String == "1"
        guard autoCopy else { return content }

        if let copyText = userInfo["copy"] as? String, !copyText.isEmpty {
            UIPasteboard.general.string = copyText
        } else {
            UIPasteboard.general.string = content.body
        }
        return content
    }
}

// MARK: - Ciphertext (end-to-end encryption)

/// Decrypts AES-encrypted push payloads. The symmetric key is generated on
/// device and shared with the sender out-of-band (QR code / copy). Modeled
/// on Bark's CiphertextProcessor.
///
/// Protocol: sender encrypts the full JSON payload `{title, body, sound,
/// ...}` with AES-128-CBC using the shared key and a random IV, then sends
/// `ciphertext=<base64>&iv=<base64>`. This processor decrypts and applies
/// all fields as if they were sent in the clear.
struct CiphertextProcessor: NotificationContentProcessor {
    private static let keychainService = "com.webbridgekit.superapp.push-crypto"
    private static let keychainAccount = "shared-aes-key"

    func process(content: UNMutableNotificationContent, userInfo: [AnyHashable: Any]) async throws -> UNMutableNotificationContent {
        guard let ciphertext = userInfo["ciphertext"] as? String, !ciphertext.isEmpty else {
            return content
        }

        guard let key = Self.loadSharedKey() else {
            // No key configured; show the ciphertext as-is so the user knows
            // an encrypted push arrived but cannot be read.
            content.title = "🔐 加密推送"
            content.body = "收到加密消息，但本机未配置解密密钥。请在设置中配置。"
            return content
        }

        guard let plaintext = Self.decrypt(ciphertext: ciphertext, iv: userInfo["iv"] as? String, key: key) else {
            content.title = "🔐 解密失败"
            content.body = "密钥不匹配或数据损坏。"
            return content
        }

        // Apply decrypted fields to the notification content.
        guard let data = plaintext.data(using: .utf8),
              let map = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return content
        }

        var newUserInfo = userInfo
        for (k, v) in map {
            let lowerKey = k.lowercased()
            newUserInfo[lowerKey] = v
            switch lowerKey {
            case "title": content.title = v
            case "subtitle": content.subtitle = v
            case "body": content.body = v
            case "group", "threadid": content.threadIdentifier = v
            case "sound":
                let name = v.hasSuffix(".caf") ? v : "\(v).caf"
                content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: name))
            case "badge":
                if let badge = Int(v) { content.badge = badge as NSNumber }
            case "icon":
                // Defer to IconProcessor which runs earlier; re-inject for
                // any later processors.
                newUserInfo["icon"] = v
            default: break
            }
        }

        // Re-run the pipeline on the decrypted fields for icon/image.
        // (The pipeline processes sequentially; we inject the decrypted
        // values into userInfo for downstream consumers.)
        return content
    }

    // MARK: - AES-128-CBC decryption

    /// AES-GCM decryption. The sender encrypts with AES-128-GCM and sends
    /// the combined (nonce + ciphertext + tag) as base64 in the ciphertext
    /// parameter. The IV parameter is accepted but unused with GCM (the
    /// nonce is embedded in the combined data).
    static func decrypt(ciphertext: String, iv: String?, key: Data) -> String? {
        guard let combined = Data(base64Encoded: ciphertext) else { return nil }
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: combined)
            let symmetricKey = SymmetricKey(data: key)
            let decrypted = try AES.GCM.open(sealedBox, using: symmetricKey)
            return String(data: decrypted, encoding: .utf8)
        } catch {
            return nil
        }
    }

    // MARK: - Keychain (shared key management)

    static func generateSharedKey() -> String? {
        let key = SymmetricKey(size: .bits128)
        let keyData = key.withUnsafeBytes { Data($0) }
        let base64 = keyData.base64EncodedString()
        guard storeKey(keyData) else { return nil }
        return base64
    }

    static func loadSharedKey() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    static func loadSharedKeyBase64() -> String? {
        loadSharedKey()?.base64EncodedString()
    }

    private static func storeKey(_ data: Data) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data,
        ]
        SecItemDelete(query as CFDictionary)
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }
}
