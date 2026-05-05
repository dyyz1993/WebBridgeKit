import Foundation

/// Built-in skills that ship with the scaffold
public enum BuiltinSkills {

    /// Open URL skill
    public static let openURL = Skill(
        name: "open_url",
        description: "Open a URL in the browser or a mini app",
        category: .navigation,
        icon: "safari",
        execute: { context in
            guard let url = context.parameters["url"] as? String else {
                throw SkillError.invalidParameters(skillId: "open_url", expected: "url")
            }
            return .success(data: ["url": url, "status": "opened"])
        }
    )

    /// Share content skill
    public static let share = Skill(
        name: "share",
        description: "Share content via system share sheet",
        category: .communication,
        icon: "square.and.arrow.up",
        execute: { context in
            guard let content = context.parameters["content"] as? String else {
                throw SkillError.invalidParameters(skillId: "share", expected: "content")
            }
            return .success(data: ["content": content, "status": "shared"])
        }
    )

    /// Scan QR code skill
    public static let scanQR = Skill(
        name: "scan_qr",
        description: "Scan a QR code using the device camera",
        category: .media,
        icon: "qrcode.viewfinder",
        execute: { _ in
            return .success(data: ["status": "scanner_ready"])
        }
    )

    /// Get device info skill
    public static let deviceInfo = Skill(
        name: "device_info",
        description: "Get current device information",
        category: .device,
        icon: "iphone",
        execute: { _ in
            return .success(data: [
                "platform": "iOS",
                "model": "iPhone",
                "systemVersion": "18.0"
            ])
        }
    )

    /// Clear cache skill
    public static let clearCache = Skill(
        name: "clear_cache",
        description: "Clear all cached data",
        category: .data,
        icon: "trash",
        execute: { _ in
            return .success(data: ["status": "cleared"])
        }
    )

    /// All built-in skills
    public static let all: [Skill] = [openURL, share, scanQR, deviceInfo, clearCache]
}
