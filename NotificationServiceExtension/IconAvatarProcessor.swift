import CryptoKit
import Foundation
import Intents
import OSLog
import UIKit
import UserNotifications

private let avatarLog = Logger(subsystem: "com.webbridgekit.superapp.nse", category: "avatar")

/// Bark IconProcessor pattern: presents a push's custom `icon` as the
/// notification avatar. iOS renders communication notifications
/// (INSendMessageIntent-donated) with the sender's circular avatar in place
/// of the app icon — attachments (UNNotificationAttachment) only show as a
/// thumbnail on the EXPANDED notification and can never occupy the leading
/// icon slot, so this intent donation is the only mechanism that puts a
/// sender-chosen image where the app icon would be.
///
/// Runs on the DECRYPTED payload (PushCrypto merges decrypted fields into
/// userInfo) so encrypted pushes get avatars too.
enum IconAvatarProcessor {

    /// NSE memory is tight; refuse anything beyond a generous icon size.
    private static let maxIconBytes = 5 * 1024 * 1024

    static func apply(
        to content: UNMutableNotificationContent,
        userInfo: [AnyHashable: Any]
    ) async -> UNMutableNotificationContent {
        guard let iconString = userInfo["icon"] as? String,
              let iconURL = URL(string: iconString),
              iconURL.scheme?.lowercased() == "https",
              iconURL.host?.isEmpty == false
        else {
            record("no-icon")
            return content
        }
        guard let imageData = await downloadIconData(from: iconURL) else {
            record("download-failed \(iconURL.absoluteString)")
            return content
        }

        let avatar = INImage(imageData: imageData)
        var senderName = PersonNameComponents()
        senderName.nickname = content.title

        let sender = INPerson(
            personHandle: INPersonHandle(value: "", type: .unknown),
            nameComponents: senderName,
            displayName: content.title,
            image: avatar,
            contactIdentifier: nil,
            customIdentifier: nil,
            isMe: false,
            suggestionType: .none
        )
        let me = INPerson(
            personHandle: INPersonHandle(value: "", type: .unknown),
            nameComponents: nil,
            displayName: nil,
            image: nil,
            contactIdentifier: nil,
            customIdentifier: nil,
            isMe: true,
            suggestionType: .none
        )
        // Bark's hard-won note (IconProcessor.swift): with a single
        // recipient iOS drops the subtitle; a second placeholder keeps it.
        var placeholderName = PersonNameComponents()
        placeholderName.nickname = content.title
        let placeholder = INPerson(
            personHandle: INPersonHandle(value: "", type: .unknown),
            nameComponents: placeholderName,
            displayName: content.title,
            image: avatar,
            contactIdentifier: nil,
            customIdentifier: nil
        )

        let intent = INSendMessageIntent(
            recipients: [me, placeholder],
            outgoingMessageType: .outgoingMessageText,
            content: content.body,
            speakableGroupName: INSpeakableString(spokenPhrase: content.subtitle),
            conversationIdentifier: content.threadIdentifier,
            serviceName: nil,
            sender: sender,
            attachments: nil
        )
        intent.setImage(avatar, forParameterNamed: \.speakableGroupName)

        let interaction = INInteraction(intent: intent, response: nil)
        interaction.direction = .incoming
        do {
            try await interaction.donate()
        } catch {
            avatarLog.error("avatar donate failed: \(error.localizedDescription, privacy: .public)")
            record("donate-failed \(error.localizedDescription)")
            return content
        }
        do {
            guard let updated = try content.updating(from: intent)
                as? UNMutableNotificationContent
            else {
                record("updating-cast-failed")
                return content
            }
            avatarLog.info("avatar intent applied ok")
            record("ok")
            return updated
        } catch {
            avatarLog.error("avatar updating failed: \(error.localizedDescription, privacy: .public)")
            record("updating-failed \(error.localizedDescription)")
            return content
        }
    }

    /// Best-effort one-line outcome of the last avatar attempt, dropped at the
    /// app-group container root so a Wi-Fi-paired `devicectl copy from` can
    /// read it without USB syslog (NSE processes are invisible to the
    /// simulator, and device console streams need a cable).
    private static func record(_ outcome: String) {
        avatarLog.info("avatar result: \(outcome, privacy: .public)")
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.webbridgekit.superapp")
        else { return }
        let stamp = Int(Date().timeIntervalSince1970)
        // Diag/ subdirectory: devicectl can only pull directories out of the
        // app-group container over Wi-Fi (single root files error out).
        let diag = container.appendingPathComponent("Library/Diag", isDirectory: true)
        try? FileManager.default.createDirectory(at: diag, withIntermediateDirectories: true)
        try? Data("\(stamp) \(outcome)\n".utf8)
            .write(to: diag.appendingPathComponent("nse_avatar_result.txt"), options: .atomic)
    }

    // MARK: - Download + app-group disk cache

    /// Repeated pushes carrying the same icon URL must not re-download on
    /// every notification (trend-report bots push hourly with one icon);
    /// cache entries never expire, matching Bark's ImageCache behavior.
    private static var cacheDirectory: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.webbridgekit.superapp")?
            .appendingPathComponent("Library/IconCache", isDirectory: true)
    }

    private static func downloadIconData(from url: URL) async -> Data? {
        if let cached = cachedData(for: url) { return cached }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              data.count <= maxIconBytes,
              UIImage(data: data) != nil
        else { return nil }

        storeCache(data, for: url)
        return data
    }

    private static func cachedData(for url: URL) -> Data? {
        guard let cacheDirectory else { return nil }
        return try? Data(contentsOf: cacheDirectory.appendingPathComponent(cacheFileName(for: url)))
    }

    private static func storeCache(_ data: Data, for url: URL) {
        guard let cacheDirectory else { return }
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        try? data.write(
            to: cacheDirectory.appendingPathComponent(cacheFileName(for: url)),
            options: .atomic
        )
    }

    private static func cacheFileName(for url: URL) -> String {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
