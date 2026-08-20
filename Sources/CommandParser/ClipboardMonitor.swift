//
//  ClipboardMonitor.swift
//  WebBridgeKit
//

import Foundation
import UIKit

public final class ClipboardMonitor: Sendable {
    public static let shared = ClipboardMonitor()

    private let commandPrefix = "【WebBridgeKit】"
    private let urlSchemePrefix = "wbsk://command"
    private let appCommandURLPrefix = "webbridgekit://command"
    private let minBase64Length = 16

    private init() {}

    /// Reads the pasteboard string on the calling thread.
    ///
    /// Never hops to the main thread for this read: `.string` may force the
    /// pasteboard daemon into an expensive HTML→text coercion (synchronous
    /// XPC round-trip). Doing that on the main thread during the scene
    /// activation transition froze the app until the 0x8BADF00D watchdog
    /// killed it (SuperApp-2026-08-20 hang reports: main thread stuck in
    /// `semaphore_wait_trap` under `_UIConcretePasteboard string`).
    /// Callers that need the value should run this on a background queue.
    public func readClipboard() -> String? {
        UIPasteboard.general.string
    }

    public func looksLikeCommand(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        if trimmed.hasPrefix(commandPrefix) {
            return true
        }

        if trimmed.lowercased().hasPrefix(urlSchemePrefix) {
            return true
        }

        if trimmed.lowercased().hasPrefix(appCommandURLPrefix) {
            return true
        }

        if isLikelyBase64(trimmed) {
            return true
        }

        return false
    }

    public func clearLastClipboardHash() {
    }

    private func isLikelyBase64(_ text: String) -> Bool {
        guard text.count >= minBase64Length else { return false }

        let base64Pattern = "^[A-Za-z0-9+/_-]+=*$"
        guard let regex = try? NSRegularExpression(pattern: base64Pattern) else { return false }
        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, range: range) != nil
    }
}
