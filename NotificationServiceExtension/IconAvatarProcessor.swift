import CryptoKit
import Foundation
import Intents
import UIKit
import UserNotifications

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
              iconURL.host?.isEmpty == false,
              let imageData = await downloadIconData(from: iconURL)
        else { return content }

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
            guard let updated = try content.updating(from: intent)
                as? UNMutableNotificationContent
            else { return content }
            return updated
        } catch {
            return content
        }
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
