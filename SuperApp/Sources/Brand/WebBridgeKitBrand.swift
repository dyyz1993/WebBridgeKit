import UIKit

/// Central access point for the Drel product mark.
///
/// Functional UI icons remain Lucide icons. This asset is reserved for Drel
/// identity surfaces. WebBridgeKit remains the separately branded SDK beneath
/// the product.
enum DrelBrand {
    static let imageName = "DrelBrand"

    static var image: UIImage? {
        UIImage(named: imageName)?.withRenderingMode(.alwaysOriginal)
    }
}
