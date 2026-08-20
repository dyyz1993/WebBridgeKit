import Foundation

/// Server build identity exposed via `/health`. The shanbox deployment is a
/// manually synced source tree (no git remote), so this constant is the only
/// reliable way to tell WHICH server code a phone is talking to.
///
/// RULE: bump `current` on every behavioral server change that ships to
/// shanbox. When diagnosing any client/server mismatch, check this value
/// FIRST — a stale server explains many "the fix doesn't work" reports.
enum ServerVersion {
    /// - 2026.08.20-1: empty-body Bark pushes (撤回/清角标), passive pushes
    ///   omit `aps.sound`, `/health` exposes this version.
    static let current = "2026.08.20-1"
}
