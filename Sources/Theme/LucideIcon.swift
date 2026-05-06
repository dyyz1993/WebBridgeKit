import UIKit

public enum LucideIcon: String, CaseIterable {
    case home = "house.fill"
    case inbox = "tray.fill"
    case compass = "compass.fill"
    case settings = "gearshape.fill"

    case copy = "doc.on.doc"
    case scan = "qrcode.viewfinder"
    case search = "magnifyingglass"
    case send = "paperplane.fill"
    case share = "square.and.arrow.up"
    case trash = "trash"
    case plus = "plus"
    case xmark = "xmark"
    case check = "checkmark"
    case edit = "pencil"
    case refresh = "arrow.clockwise"
    case download = "arrow.down.circle"
    case upload = "arrow.up.circle"

    case bell = "bell.fill"
    case bellOff = "bell.slash.fill"
    case link = "link"
    case image = "photo"
    case tag = "tag"
    case star = "star.fill"
    case bookmark = "bookmark.fill"
    case clock = "clock.fill"
    case pin = "pin.fill"
    case shield = "shield.fill"
    case key = "key.fill"
    case lock = "lock.fill"

    case info = "info.circle.fill"
    case warning = "exclamationmark.triangle.fill"
    case error = "xmark.circle.fill"
    case success = "checkmark.circle.fill"

    case chevronRight = "chevron.right"
    case chevronLeft = "chevron.left"
    case arrowLeft = "arrow.left"
    case arrowRight = "arrow.right"
    case arrowUp = "arrow.up"
    case arrowDown = "arrow.down"

    case chevronDown = "chevron.down"

    case bug = "exclamationmark.bubble.fill"
    case terminal = "chevron.left.forwardslash.chevron.right"
    case chartBar = "chart.bar.fill"

    case docText = "doc.text"
    case docTextFill = "doc.text.fill"
    case appFill = "app.fill"
    case appBadge = "app.badge.fill"
    case pinOutline = "pin"
    case starOutline = "star"
    case squarePencil = "square.and.pencil"
    case xmarkCircle = "xmark.circle"
    case linkBadgePlus = "link.badge.plus"
    case paperplane = "paperplane"

    case volume = "speaker.wave.2.fill"
    case mic = "mic.fill"
    case camera = "camera.fill"

    case server = "desktopcomputer"
    case hardDrive = "internaldrive"
    case network = "network"
    case globe = "globe"
    case doc = "doc.fill"
    case folder = "folder.fill"

    public func image(pointSize: CGFloat = 20, weight: UIImage.SymbolWeight = .medium) -> UIImage? {
        let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
        return UIImage(systemName: self.rawValue, withConfiguration: config)
    }

    public func templateImage(pointSize: CGFloat = 20, weight: UIImage.SymbolWeight = .medium) -> UIImage? {
        let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
        return UIImage(systemName: self.rawValue, withConfiguration: config)?.withRenderingMode(.alwaysTemplate)
    }
}
