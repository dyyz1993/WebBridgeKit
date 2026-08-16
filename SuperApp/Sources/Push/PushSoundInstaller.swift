import Foundation
import WebBridgeKit

/// Copies the bundled push ringtones into Library/Sounds on first launch.
///
/// UNNotificationSound resolves names against the app bundle and the
/// container's Library/Sounds; Library/Sounds is the location Bark uses for
/// user-imported sounds and is the most reliable of the two on device. Some
/// bundle-root lookups were observed falling back to the default alert even
/// with canonical PCM caf files at the bundle root, so mirror the library
/// into Library/Sounds as well — the copy is idempotent and cheap (~1 MB).
enum PushSoundInstaller {

    static func install() {
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let soundsDirectory = library.appendingPathComponent("Sounds", isDirectory: true)

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
