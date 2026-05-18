import UIKit

private class BundleFinder {}

public struct Lucide {
    public static var bundle: Bundle {
        Bundle(for: BundleFinder.self)
    }
}

public extension UIImage {
    convenience init?(lucideId: String) {
        let assetName: String
        switch lucideId {
        case "book-image":
            assetName = "book-image-lucide"
        case "file-image":
            assetName = "file-image-lucide"
        default:
            assetName = lucideId
        }
        self.init(named: assetName, in: Lucide.bundle, compatibleWith: nil)
    }
}
