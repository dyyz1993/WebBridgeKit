import AudioToolbox
import AVFAudio
import Foundation
import UserNotifications

/// Records incoming push payloads to shared plist files so the main app can
/// import them into its message store on next foreground — mirroring Bark's
/// Notification Service Extension approach — and extends `call=1` pushes
/// with a synthesized 30-second looping ringtone (Bark CallProcessor pattern)
/// so they ring like a phone call instead of a single alert chime.
final class NotificationService: UNNotificationServiceExtension {

    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttempt: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        self.bestAttempt = (request.content.mutableCopy() as? UNMutableNotificationContent)

        // Encrypted pushes are decrypted first so both the presented banner
        // and the recorded plist carry the readable fields; the server only
        // ever saw the ciphertext.
        let (content, recordedUserInfo) = PushCrypto.process(
            self.bestAttempt ?? UNMutableNotificationContent(),
            userInfo: request.content.userInfo
        )
        self.bestAttempt = content

        // Write the full (decrypted when applicable) payload to the App
        // Group shared container so the main app can import it even if the
        // user never taps the notification.
        recordPayload(recordedUserInfo)

        contentHandler(content)
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler, let bestAttempt {
            contentHandler(bestAttempt)
        }
    }

    // MARK: - Call=1 long ringtone (Bark CallProcessor pattern)

    private static func isCall(userInfo: [AnyHashable: Any]) -> Bool {
        switch userInfo["call"] {
        case let value as String:
            return value == "1" || value.lowercased() == "true"
        case let value as NSNumber:
            return value.boolValue
        default:
            return false
        }
    }

    /// Named sounds live in the app group's Library/Sounds (mirrored there by
    /// PushSoundInstaller) because this extension cannot read the main app's
    /// bundle. Loop-synthesized 30s variants are cached next to them.
    private static var sharedSoundsDirectory: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.webbridgekit.superapp")?
            .appendingPathComponent("Library/Sounds")
    }

    private static let longSoundPrefix = "wbk.sounds.30s"
    private static let fallbackSoundName = "multiwayinvitation"

    private static func applyLongRingtone(
        to content: UNMutableNotificationContent,
        userInfo: [AnyHashable: Any]
    ) -> UNMutableNotificationContent {
        let rawSound = ((userInfo["aps"] as? [String: Any])?["sound"] as? String) ?? content.sound
        // Named sounds carry the .caf extension (project rule); anything else
        // falls back to Bark's default call tone.
        let components = rawSound.split(separator: ".")
        let soundName: String
        if components.count == 2, let last = components.last, last.lowercased() == "caf" {
            soundName = String(components.first!)
        } else {
            soundName = fallbackSoundName
        }

        guard let longSoundURL = longSoundURL(for: soundName) else { return content }
        content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: longSoundURL.lastPathComponent))
        return content
    }

    private static func longSoundURL(for soundName: String) -> URL? {
        guard let soundsDirectory = sharedSoundsDirectory else { return nil }
        try? FileManager.default.createDirectory(at: soundsDirectory, withIntermediateDirectories: true)

        let longURL = soundsDirectory.appendingPathComponent("\(longSoundPrefix).\(soundName).caf")
        if FileManager.default.fileExists(atPath: longURL.path) {
            return longURL
        }

        // The shared mirror is the primary source; the extension bundle also
        // carries the ringtones as a fallback.
        var sourceURL = soundsDirectory.appendingPathComponent("\(soundName).caf")
        if !FileManager.default.fileExists(atPath: sourceURL.path) {
            sourceURL = Bundle.main.url(forResource: soundName, withExtension: "caf") ?? sourceURL
        }
        guard FileManager.default.fileExists(atPath: sourceURL.path) else { return nil }

        return loopToDuration(inputFile: sourceURL, outputFile: longURL)
    }

    /// Repeats the source audio until it reaches the target duration
    /// (AVAudioFile read-loop, truncating the final pass) — the same
    /// synthesis Bark's CallProcessor uses to synthesize 30s ringtones.
    private static func loopToDuration(
        inputFile: URL,
        outputFile: URL,
        targetDuration: TimeInterval = 30
    ) -> URL? {
        do {
            let audioFile = try AVAudioFile(forReading: inputFile)
            let format = audioFile.processingFormat
            let sampleRate = format.sampleRate
            let targetFrames = AVAudioFramePosition(targetDuration * sampleRate)
            var writtenFrames: AVAudioFramePosition = 0
            let outputAudioFile = try AVAudioFile(forWriting: outputFile, settings: format.settings)

            while writtenFrames < targetFrames {
                guard let buffer = AVAudioPCMBuffer(
                    pcmFormat: format,
                    frameCapacity: AVAudioFrameCount(audioFile.length)
                ) else { return nil }
                try audioFile.read(into: buffer)

                let remainingFrames = targetFrames - writtenFrames
                if AVAudioFramePosition(buffer.frameLength) > remainingFrames {
                    guard let truncated = AVAudioPCMBuffer(
                        pcmFormat: format,
                        frameCapacity: AVAudioFrameCount(remainingFrames)
                    ) else { return nil }
                    let channelCount = Int(format.channelCount)
                    for channel in 0..<channelCount {
                        guard let source = buffer.floatChannelData?[channel],
                              let destination = truncated.floatChannelData?[channel] else { continue }
                        memcpy(destination, source, Int(remainingFrames) * MemoryLayout<Float>.size)
                    }
                    truncated.frameLength = AVAudioFrameCount(remainingFrames)
                    try outputAudioFile.write(from: truncated)
                    break
                } else {
                    try outputAudioFile.write(from: buffer)
                    writtenFrames += AVAudioFramePosition(buffer.frameLength)
                }
                audioFile.framePosition = 0
            }
            return outputFile
        } catch {
            return nil
        }
    }

    // MARK: - Shared-file recording (Bark pattern: ArchiveProcessor)

    /// Writes the complete custom payload (everything except `aps`) so the
    /// main app can rebuild a full-fidelity message — image, qr, route,
    /// approval, and the server-assigned `messageId` that dedupes this
    /// replay against banner taps and server-history imports.
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
        // Preserve every custom top-level key; drop `aps` and anything a
        // plist cannot represent so the write can never fail on exotic values.
        for (rawKey, value) in userInfo where (rawKey as? String) != "aps" {
            guard let key = rawKey as? String,
                  PropertyListSerialization.isValidPropertyList(value)
            else { continue }
            dict[key] = value
        }

        let fileName = "msg-\(Int(Date().timeIntervalSince1970 * 1000)).plist"
        let fileURL = pendingDir.appendingPathComponent(fileName)
        NSDictionary(dictionary: dict).write(to: fileURL, atomically: true)
    }
}
