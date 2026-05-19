import UIKit

private class BundleFinder {}

public struct Lucide {
    public static var bundle: Bundle {
        Bundle(for: BundleFinder.self)
    }
}

public extension UIImage {
    convenience init?(lucideId: String) {
        let assetName = Lucide.assetName(for: lucideId)
        self.init(named: assetName, in: Lucide.bundle, compatibleWith: nil)
    }
}

private extension Lucide {
    static func assetName(for lucideId: String) -> String {
        aliases[lucideId] ?? lucideId
    }

    static let aliases: [String: String] = [
        "alert-triangle": "triangle-alert",
        "bar-chart-2": "chart-bar",
        "check-circle": "circle-check",
        "download-cloud": "cloud-download",
        "file-json": "file-code",
        "link-plus": "link",
        "more-horizontal": "ellipsis",
        "refresh": "refresh-cw",
        "x-circle": "circle-x"
    ]
}
