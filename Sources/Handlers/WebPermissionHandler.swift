//
//  WebPermissionHandler.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-13.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import AVFoundation
import CoreLocation
import Foundation
import UIKit
import WebKit
import UserNotifications

// Framework imports

/// 权限申请处理器
public class WebPermissionHandler: BaseWebNativeHandler {

    enum PermissionType: String {
        case location = "location"
        case notification = "notification"
        case camera = "camera"
        case microphone = "microphone"
    }

    /// 处理权限申请请求
    /// - Parameters:
    ///   - body: 包含 type (如 "camera", "notification")
    ///   - completion: 结果回调
    public override func handle(body: [String: Any], completion: @escaping (Any) -> Void) {
        guard let typeString = body["type"] as? String,
              let type = PermissionType(rawValue: typeString) else {
            reject(error: "Invalid permission type", completion: completion)
            return
        }

        switch type {
        case .location:
            requestLocationPermission(completion: completion)
        case .notification:
            requestNotificationPermission(completion: completion)
        case .camera:
            requestAVPermission(type: .video, completion: completion)
        case .microphone:
            requestAVPermission(type: .audio, completion: completion)
        }
    }

    // MARK: - Location Permission

    private func requestLocationPermission(completion: @escaping (Any) -> Void) {
        let locationManager = CLLocationManager()

        guard CLLocationManager.locationServicesEnabled() else {
            reject(error: "Location services disabled", completion: completion)
            return
        }

        let status = CLLocationManager.authorizationStatus()
        let granted = status == .authorizedWhenInUse || status == .authorizedAlways

        resolve(["granted": granted, "status": status.rawValue], completion: completion)
    }

    // MARK: - Notification Permission

    private func requestNotificationPermission(completion: @escaping (Any) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                self.reject(error: error.localizedDescription, completion: completion)
            } else {
                self.resolve(["granted": granted], completion: completion)
            }
        }
    }

    // MARK: - AV Permission (Camera/Microphone)

    private func requestAVPermission(type: AVMediaType, completion: @escaping (Any) -> Void) {
        switch type {
        case AVMediaType.video:
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            let granted = status == .authorized
            resolve(["granted": granted, "status": status.rawValue], completion: completion)

        case AVMediaType.audio:
            let status = AVCaptureDevice.authorizationStatus(for: .audio)
            let granted = status == .authorized
            resolve(["granted": granted, "status": status.rawValue], completion: completion)

        default:
            reject(error: "Unknown media type", completion: completion)
        }
    }
}
