//
//  HTMLAppBridgeCapabilityPolicy.swift
//  WebBridgeKit
//

import Foundation

/// Adopted by native handlers that keep hardware or sensor work alive after
/// the original JavaScript request has completed.
public protocol HTMLAppCapabilityRevocationHandling: AnyObject {
    func htmlAppCapabilityDidRevoke()
}

/// The single mapping between JavaScript Bridge actions and managed-PWA
/// capabilities. Actions not listed here remain available to ordinary web
/// pages and do not receive access to protected native data or hardware.
public enum HTMLAppBridgeCapabilityPolicy {
    public static func capability(for action: String, body: [String: Any]) -> HTMLAppCapability? {
        switch action {
        case "bluetooth": return .bluetooth
        case "camera", "videoStream": return .camera
        case "clipboard": return .clipboard
        case "contacts": return .contacts
        // gesture/layout/screen：纯容器交互，不涉及用户隐私，免授权
        case "gesture", "layout", "screen": return nil
        case "file": return .fileImport
        case "getLocation": return .location
        case "audioLevel", "speech": return .microphone
        // mirroring：只读投屏状态查询，不涉及用户隐私，免授权
        case "mirroring": return nil
        case "photo": return .photoLibrary
        case "scan": return .scan
        case "sensors": return .motion
        case "share": return .share
        case "showNotification": return .notification
        case "systemExtra":
            switch parameters(in: body)["action"] as? String {
            case "authenticate": return .biometrics
            case "setBadge": return .notification
            case "setTorch": return .camera
            default: return .deviceControl
            }
        case "requestPermission":
            let type = parameters(in: body)["type"] as? String
                ?? parameters(in: body)["permission"] as? String
            return type.flatMap(HTMLAppCapability.init(rawValue:))
        case "media":
            let operation = parameters(in: body)["action"] as? String
            switch operation {
            case "saveImage": return .photoLibrary
            case "saveFile", "uploadFile": return .fileExport
            default: return nil
            }
        default:
            return nil
        }
    }

    private static func parameters(in body: [String: Any]) -> [String: Any] {
        body["params"] as? [String: Any] ?? body
    }
}
