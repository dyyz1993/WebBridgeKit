import AVFoundation
import Foundation

/// Plays a named push sound while the app is foreground.
///
/// Foreground presentation (.sound option) has a long-standing iOS quirk:
/// named sounds frequently fall back to the default alert tone even when
/// the file resolves fine in background delivery. Since the sound library
/// ships in the bundle and mirrors into Library/Sounds, play it ourselves
/// with AVAudioPlayer and leave .sound out of the presentation options.
final class PushAlertSoundPlayer {

    static let shared = PushAlertSoundPlayer()

    private var player: AVAudioPlayer?

    private init() {
        // .ambient obeys the silent switch and mixes with other audio,
        // matching how system notification sounds behave.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: .mixWithOthers)
    }

    /// Returns true when the name resolved to a playable file and playback
    /// started. "default"/empty names are intentionally not handled here —
    /// those go through the system presentation path.
    @discardableResult
    func play(named name: String) -> Bool {
        guard !name.isEmpty, name != "default" else { return false }
        guard let url = resolveSoundURL(named: name),
              let audioPlayer = try? AVAudioPlayer(contentsOf: url) else {
            return false
        }
        player = audioPlayer
        audioPlayer.play()
        return true
    }

    private func resolveSoundURL(named name: String) -> URL? {
        // Trim an explicit extension if present; canonical lookups use the
        // base name.
        let baseName = (name as NSString).deletingPathExtension

        // Bundle first — it always holds the complete 32-sound library and
        // does not depend on the first-launch mirror having finished.
        if let bundled = Bundle.main.url(forResource: baseName, withExtension: "caf") {
            return bundled
        }

        // Library/Sounds covers user-imported custom sounds and the
        // PushSoundInstaller mirror.
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let librarySound = library
            .appendingPathComponent("Sounds", isDirectory: true)
            .appendingPathComponent("\(baseName).caf")
        if FileManager.default.fileExists(atPath: librarySound.path) {
            return librarySound
        }
        return nil
    }
}
