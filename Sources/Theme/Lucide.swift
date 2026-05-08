import UIKit

private class BundleFinder {}

public struct Lucide {
    public static var bundle: Bundle {
        Bundle(for: BundleFinder.self)
    }
}

public extension UIImage {
    convenience init?(lucideId: String) {
        self.init(named: lucideId, in: Lucide.bundle, compatibleWith: nil)
    }
}
