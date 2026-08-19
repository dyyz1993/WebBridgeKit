import Foundation
import WebBridgeKit

/// Copies the bundled push ringtones into the shared app-group Library/Sounds
/// on first launch.
///
/// The NotificationServiceExtension cannot read the main app's container or
/// bundle; the app group's Library/Sounds is the shared, documented location
/// both processes can resolve named sounds from (Bark uses the same layout).
/// The copy is idempotent and cheap (~1 MB).
enum PushSoundInstaller {

    static let appGroupIdentifier = "group.com.webbridgekit.superapp"

    static func install() {
        // App Group not yet registered with Apple; mirror to the main
        // container meanwhile. The NSE icon/image processors work without
        // it; CallProcessor will activate once the group is provisioned.
        let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) ?? FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]

        let soundsDirectory = groupURL
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Sounds", isDirectory: true)

        // Remove synthesized 30s call ringtones: delivering one crashed
        // SpringBoard on iOS 18.7.3 (respring on push arrival). Cached
        // copies must not linger — any of them could take SpringBoard down
        // again on the next call=1 delivery attempt.
        if let cached = try? FileManager.default.contentsOfDirectory(
            at: soundsDirectory,
            includingPropertiesForKeys: nil
        ) {
            for url in cached where url.lastPathComponent.hasPrefix("wbk.sounds.30s") {
                try? FileManager.default.removeItem(at: url)
            }
        }

        do {
            try FileManager.default.createDirectory(at: soundsDirectory, withIntermediateDirectories: true)
        } catch {
            return
        }

        guard let bundled = Bundle.main.urls(forResourcesWithExtension: "caf", subdirectory: nil) else { return }
        for source in bundled {
            let destination = soundsDirectory.appendingPathComponent(source.lastPathComponent)
            let needsCopy: Bool
            if let existing = try? destination.resourceValues(forKeys: [.fileSizeKey]),
               let bundledSize = try? source.resourceValues(forKeys: [.fileSizeKey]),
               existing.fileSize == bundledSize.fileSize {
                needsCopy = false
            } else {
                needsCopy = true
            }
            guard needsCopy else { continue }
            try? FileManager.default.removeItem(at: destination)
            try? FileManager.default.copyItem(at: source, to: destination)
        }
    }
}
