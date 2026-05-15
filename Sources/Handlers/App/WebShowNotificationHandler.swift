//
//  WebShowNotificationHandler.swift
//  WebBridgeKit
//
//  Created on 2026-05-14.
//

import Foundation
import UIKit
import UserNotifications

/// 显示本地通知（非 APNs）
/// 由 App 内发起的系统级通知弹窗
public class WebShowNotificationHandler: BaseWebNativeHandler {

    public override func handle(body: [String: Any], completion: @escaping (Any) -> Void) {
        let title = body["title"] as? String ?? ""
        let bodyText = body["body"] as? String ?? ""
        let imageUrl = body["image"] as? String
        let tapAction = body["url"] as? String

        guard !title.isEmpty || !bodyText.isEmpty else {
            reject(error: "title or body is required", completion: completion)
            return
        }

        runOnMainThread { [weak self] in
            guard let self = self else { return }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = bodyText
            content.sound = .default

            // 附加图片
            if let imageUrl = imageUrl, let url = URL(string: imageUrl),
               let imageData = try? Data(contentsOf: url) {
                let tempDir = FileManager.default.temporaryDirectory
                let tempFile = tempDir.appendingPathComponent("notif_\(UUID().uuidString).jpg")
                try? imageData.write(to: tempFile)
                if let attachment = try? UNNotificationAttachment(
                    identifier: "image",
                    url: tempFile,
                    options: nil
                ) {
                    content.attachments = [attachment]
                }
            }

            // 附加跳转 URL（传递给用户点击通知时的处理）
            if let tapAction = tapAction {
                content.userInfo = ["url": tapAction]
            }

            // 立即触发本地通知
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: trigger
            )

            UNUserNotificationCenter.current().add(request) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        self.reject(error: "Failed to show notification: \(error.localizedDescription)", completion: completion)
                    } else {
                        self.resolve(["shown": true, "title": content.title], completion: completion)
                    }
                }
            }
        }
    }
}
