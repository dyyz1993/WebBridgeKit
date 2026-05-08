import UIKit

public enum LucideIcon: CaseIterable {
    case home, inbox, compass, settings
    case copy, scan, search, send, share, trash, plus, xmark, check, edit, refresh, download, upload
    case bell, bellOff, link, image, tag, star, bookmark, clock, pin, shield, key, lock
    case info, warning, error, success
    case chevronRight, chevronLeft, arrowLeft, arrowRight, arrowUp, arrowDown, chevronDown
    case bug, terminal, chartBar
    case docText, docTextFill, appFill, appBadge, pinOutline, starOutline, squarePencil, xmarkCircle, linkBadgePlus, paperplane
    case volume, mic, camera
    case server, hardDrive, network, globe, doc, folder

    var lucideId: String {
        switch self {
        case .home: return "house"
        case .inbox: return "inbox"
        case .compass: return "compass"
        case .settings: return "settings"
        case .copy: return "copy"
        case .scan: return "scan-line"
        case .search: return "search"
        case .send: return "send"
        case .share: return "share-2"
        case .trash: return "trash-2"
        case .plus: return "plus"
        case .xmark: return "x"
        case .check: return "check"
        case .edit: return "pencil"
        case .refresh: return "refresh-cw"
        case .download: return "download"
        case .upload: return "upload"
        case .bell: return "bell"
        case .bellOff: return "bell-off"
        case .link: return "link"
        case .image: return "image"
        case .tag: return "tag"
        case .star: return "star"
        case .bookmark: return "bookmark"
        case .clock: return "clock"
        case .pin: return "pin"
        case .shield: return "shield"
        case .key: return "key"
        case .lock: return "lock"
        case .info: return "info"
        case .warning: return "alert-triangle"
        case .error: return "x-circle"
        case .success: return "check-circle"
        case .chevronRight: return "chevron-right"
        case .chevronLeft: return "chevron-left"
        case .arrowLeft: return "arrow-left"
        case .arrowRight: return "arrow-right"
        case .arrowUp: return "arrow-up"
        case .arrowDown: return "arrow-down"
        case .chevronDown: return "chevron-down"
        case .bug: return "bug"
        case .terminal: return "terminal"
        case .chartBar: return "bar-chart-2"
        case .docText: return "file-text"
        case .docTextFill: return "file-text"
        case .appFill: return "app-window"
        case .appBadge: return "app-window"
        case .pinOutline: return "pin"
        case .starOutline: return "star"
        case .squarePencil: return "square-pen"
        case .xmarkCircle: return "x-circle"
        case .linkBadgePlus: return "link-plus"
        case .paperplane: return "send"
        case .volume: return "volume-2"
        case .mic: return "mic"
        case .camera: return "camera"
        case .server: return "server"
        case .hardDrive: return "hard-drive"
        case .network: return "wifi"
        case .globe: return "globe"
        case .doc: return "file-text"
        case .folder: return "folder"
        }
    }

    var sfSymbolName: String {
        switch self {
        case .home: return "house.fill"
        case .inbox: return "tray.fill"
        case .compass: return "compass.fill"
        case .settings: return "gearshape.fill"
        case .copy: return "doc.on.doc"
        case .scan: return "qrcode.viewfinder"
        case .search: return "magnifyingglass"
        case .send: return "paperplane.fill"
        case .share: return "square.and.arrow.up"
        case .trash: return "trash"
        case .plus: return "plus"
        case .xmark: return "xmark"
        case .check: return "checkmark"
        case .edit: return "pencil"
        case .refresh: return "arrow.clockwise"
        case .download: return "arrow.down.circle"
        case .upload: return "arrow.up.circle"
        case .bell: return "bell.fill"
        case .bellOff: return "bell.slash.fill"
        case .link: return "link"
        case .image: return "photo"
        case .tag: return "tag"
        case .star: return "star.fill"
        case .bookmark: return "bookmark.fill"
        case .clock: return "clock.fill"
        case .pin: return "pin.fill"
        case .shield: return "shield.fill"
        case .key: return "key.fill"
        case .lock: return "lock.fill"
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .chevronRight: return "chevron.right"
        case .chevronLeft: return "chevron.left"
        case .arrowLeft: return "arrow.left"
        case .arrowRight: return "arrow.right"
        case .arrowUp: return "arrow.up"
        case .arrowDown: return "arrow.down"
        case .chevronDown: return "chevron.down"
        case .bug: return "exclamationmark.bubble.fill"
        case .terminal: return "chevron.left.forwardslash.chevron.right"
        case .chartBar: return "chart.bar.fill"
        case .docText: return "doc.text"
        case .docTextFill: return "doc.text.fill"
        case .appFill: return "app.fill"
        case .appBadge: return "app.badge.fill"
        case .pinOutline: return "pin"
        case .starOutline: return "star"
        case .squarePencil: return "square.and.pencil"
        case .xmarkCircle: return "xmark.circle"
        case .linkBadgePlus: return "link.badge.plus"
        case .paperplane: return "paperplane"
        case .volume: return "speaker.wave.2.fill"
        case .mic: return "mic.fill"
        case .camera: return "camera.fill"
        case .server: return "desktopcomputer"
        case .hardDrive: return "internaldrive"
        case .network: return "network"
        case .globe: return "globe"
        case .doc: return "doc.fill"
        case .folder: return "folder.fill"
        }
    }

    public func image(pointSize: CGFloat = 20, weight: UIImage.SymbolWeight = .medium) -> UIImage? {
        if let img = UIImage(lucideId: lucideId) {
            let scaled = UIImage(cgImage: img.cgImage!, scale: UIScreen.main.scale, orientation: img.imageOrientation)
            return scaled.withTintColor(.label)
        }
        let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
        return UIImage(systemName: sfSymbolName, withConfiguration: config)
    }

    public func templateImage(pointSize: CGFloat = 20, weight: UIImage.SymbolWeight = .medium) -> UIImage? {
        if let img = UIImage(lucideId: lucideId) {
            let scaled = UIImage(cgImage: img.cgImage!, scale: UIScreen.main.scale, orientation: img.imageOrientation)
            return scaled.withRenderingMode(.alwaysTemplate)
        }
        let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
        return UIImage(systemName: sfSymbolName, withConfiguration: config)?.withRenderingMode(.alwaysTemplate)
    }
}
