import UIKit
import WebBridgeKit

enum NotificationSettingsOpener {
    static func open() {
        let urlString: String
        if #available(iOS 16.0, *) {
            urlString = UIApplication.openNotificationSettingsURLString
        } else {
            urlString = UIApplication.openSettingsURLString
        }

        guard let url = URL(string: urlString) else {
            StructuredLogger.shared.error("Invalid notification settings URL: \(urlString)", category: .ui)
            return
        }

        UIApplication.shared.open(url, options: [:]) { success in
            let message = "Notification settings handoff \(success ? "succeeded" : "failed"): \(urlString)"
            if success {
                StructuredLogger.shared.info(message, category: .ui)
            } else {
                StructuredLogger.shared.warning(message, category: .ui)
            }
        }
    }
}
