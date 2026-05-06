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
    private let minBase64Length = 16

    private init() {}

    public func readClipboard() -> String? {
        if Thread.isMainThread {
            return UIPasteboard.general.string
        } else {
            return DispatchQueue.main.sync {
                UIPasteboard.general.string
            }
        }
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
