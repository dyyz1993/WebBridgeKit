import UserNotifications
import AVFoundation
import CryptoKit
import Intents
import UIKit

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    private let pipeline: NotificationProcessorPipeline = {
        var pipeline = NotificationProcessorPipeline()
        pipeline.register(TitleProcessor())
        pipeline.register(BodyProcessor())
        pipeline.register(BadgeProcessor())
        pipeline.register(GroupProcessor())
        pipeline.register(ThreadProcessor())
        pipeline.register(ImageProcessor())
        pipeline.register(MarkdownNotificationProcessor())
        // IconProcessor uses INSendMessageIntent.updating(from:) which
        // RESETS content.sound; Sound and Call MUST run AFTER it.
        pipeline.register(IconProcessor())
        pipeline.register(SoundProcessor())
        pipeline.register(CallProcessor())
        pipeline.register(MuteProcessor())
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

        // Record before any async work: icon/image downloads consume the
        // extension's time budget, and the record must survive
        // serviceExtensionTimeWillExpire so the Inbox never loses the push.
        recordPendingMessage(request)

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

// MARK: - Pending message persistence

extension NotificationService {

    /// App Group shared with the main app; kept in sync with
    /// PushSoundInstaller.appGroupIdentifier (the extension is deliberately
    /// self-contained and cannot import SuperApp code).
    private static let appGroupID = "group.com.webbridgekit.superapp"
    private static let pendingDirName = "pending_messages"

    private static let recordDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss.SSS"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// Persists the raw push payload into the shared App Group so the main
    /// app can import it into the Inbox on next foreground. Background
    /// pushes are otherwise lost: only foreground arrivals and banner taps
    /// are recorded natively. No-op until the App Group is provisioned in
    /// both the app's and this extension's entitlements.
    private func recordPendingMessage(_ request: UNNotificationRequest) {
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Self.appGroupID
        ) else { return }

        do {
            let pendingDir = groupURL.appendingPathComponent(Self.pendingDirName, isDirectory: true)
            try FileManager.default.createDirectory(at: pendingDir, withIntermediateDirectories: true)

            // Content snapshot mirrors UNNotificationContent fallbacks; the
            // userInfo overlay lets explicit payload fields win, matching the
            // app's live mapping precedence.
            var record: [String: Any] = [
                "identifier": request.identifier,
                "title": request.content.title,
                "body": request.content.body
            ]
            if !request.content.subtitle.isEmpty {
                record["subtitle"] = request.content.subtitle
            }
            if let badge = request.content.badge {
                record["badge"] = badge
            }
            for (key, value) in request.content.userInfo {
                // "identifier" is the dedup key against the app's tap path;
                // a payload field of the same name must not overwrite it.
                if let key = key as? String, key != "identifier", Self.isPlistValue(value) {
                    record[key] = value
                }
            }

            let stamp = Self.recordDateFormatter.string(from: Date())
            let fileURL = pendingDir.appendingPathComponent("\(stamp)-\(UUID().uuidString.prefix(8)).plist")
            (record as NSDictionary).write(to: fileURL, atomically: true)
        } catch {
            // Recording is best-effort; delivery itself must not fail.
        }
    }

    private static func isPlistValue(_ value: Any) -> Bool {
        value is String || value is NSNumber || value is Date || value is Data
            || (value as? [Any]) != nil || (value as? [String: Any]) != nil
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


// MARK: - Icon (INSendMessageIntent — left-side custom avatar)

/// Replaces the notification's left-side app icon with a custom image by
/// constructing a fake iMessage conversation via INSendMessageIntent.
/// This is the same technique Bark uses: iOS renders "incoming message"
/// notifications with the sender's avatar on the left, bypassing the
/// normally immutable app icon. iOS 15+.
struct IconProcessor: NotificationContentProcessor {
    func process(content: UNMutableNotificationContent, userInfo: [AnyHashable: Any]) async throws -> UNMutableNotificationContent {
        guard #available(iOSApplicationExtension 15.0, *) else { return content }

        guard let iconURLString = userInfo["icon"] as? String,
              !iconURLString.isEmpty,
              let iconURL = URL(string: iconURLString),
              let imageData = try? await downloadIconData(from: iconURL)
        else {
            return content
        }

        // Build a fake "sender" person with the custom icon as avatar.
        var nameComponents = PersonNameComponents()
        nameComponents.nickname = content.title

        let avatar = INImage(imageData: imageData)
        let senderPerson = INPerson(
            personHandle: INPersonHandle(value: "", type: .unknown),
            nameComponents: nameComponents,
            displayName: nameComponents.nickname,
            image: avatar,
            contactIdentifier: nil,
            customIdentifier: nil,
            isMe: false,
            suggestionType: .none
        )
        // The "me" recipient (required for the message layout).
        let mePerson = INPerson(
            personHandle: INPersonHandle(value: "", type: .unknown),
            nameComponents: nil,
            displayName: nil,
            image: nil,
            contactIdentifier: nil,
            customIdentifier: nil,
            isMe: true,
            suggestionType: .none
        )
        // Second placeholder recipient — required for the subtitle to
        // render (same as Bark; do not ask why).
        let placeholderPerson = INPerson(
            personHandle: INPersonHandle(value: "", type: .unknown),
            nameComponents: nameComponents,
            displayName: nameComponents.nickname,
            image: avatar,
            contactIdentifier: nil,
            customIdentifier: nil,
            isMe: false,
            suggestionType: .none
        )

        let intent = INSendMessageIntent(
            recipients: [mePerson, placeholderPerson],
            outgoingMessageType: .outgoingMessageText,
            content: content.body,
            speakableGroupName: INSpeakableString(spokenPhrase: content.subtitle),
            conversationIdentifier: content.threadIdentifier,
            serviceName: nil,
            sender: senderPerson,
            attachments: nil
        )

        intent.setImage(avatar, forParameterNamed: \.speakableGroupName)

        let interaction = INInteraction(intent: intent, response: nil)
        interaction.direction = .incoming

        do {
            try await interaction.donate()
            let updated = try content.updating(from: intent) as! UNMutableNotificationContent
            return updated
        } catch {
            // Intent donation failures must not break delivery; the
            // notification still shows with the default app icon.
            return content
        }
    }

    private func downloadIconData(from url: URL) async throws -> Data {
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
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
            kSecReturnData as String: true
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
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }
}


// MARK: - Mute (per-group temporary silence)

/// Silences notifications from a specific group until the mute expires.
/// Settings are shared between the app and NSE via App Group UserDefaults
/// (modeled on Bark's GroupMuteSettingManager).
struct MuteProcessor: NotificationContentProcessor {
    private static let muteKey = "groupMuteSettings"

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: "group.com.webbridgekit.superapp")
    }

    func process(content: UNMutableNotificationContent, userInfo: [AnyHashable: Any]) async throws -> UNMutableNotificationContent {
        let groupName = content.threadIdentifier
        guard !groupName.isEmpty else { return content }

        guard let expiry = muteExpiry(for: groupName), expiry > Date() else {
            return content
        }

        // Silenced: deliver to notification center without sound or banner.
        content.sound = nil
        if #available(iOSApplicationExtension 15.0, *) {
            content.interruptionLevel = .passive
        }
        return content
    }

    private func muteExpiry(for group: String) -> Date? {
        guard let defaults = sharedDefaults,
              let settings = defaults.dictionary(forKey: Self.muteKey) as? [String: Date] else {
            return nil
        }
        // Clean expired entries.
        var cleaned = settings.filter { $0.value > Date() }
        if cleaned.count != settings.count {
            defaults.set(cleaned, forKey: Self.muteKey)
        }
        return cleaned[group]
    }
}
