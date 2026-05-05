//
//  WebPermissionManager.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-14.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import AVFoundation
import CoreLocation
import Foundation
import Speech
import UserNotifications

// Framework imports

/// 权限管理器 - 统一管理所有权限状态
public class WebPermissionManager {

    public static let shared = WebPermissionManager()

    private init() {}

    /// 检查所有权限状态
    /// - Parameter completion: 包含所有权限状态字典数组的回调
    public func checkAllPermissions(completion: @escaping ([[String: Any]]) -> Void) {
        var permissions: [[String: Any]] = []

        // 1. 位置权限 (同步)
        permissions.append(checkLocationPermission())

        // 2. 相机权限 (同步)
        permissions.append(checkCameraPermission())

        // 3. 麦克风权限 (同步)
        permissions.append(checkMicrophonePermission())

        // 4. 语音识别权限 (同步)
        permissions.append(checkSpeechPermission())

        // 5. 通知权限 (异步)
        checkNotificationPermission { notificationPermission in
            permissions.append(notificationPermission)
            completion(permissions)
        }
    }

    // MARK: - Individual Permission Checks

    /// 检查位置权限
    public func checkLocationPermission() -> [String: Any] {
        let status = CLLocationManager.authorizationStatus()
        let statusString: String
        let granted: Bool

        switch status {
        case .notDetermined:
            statusString = "notDetermined"
            granted = false
        case .restricted:
            statusString = "restricted"
            granted = false
        case .denied:
            statusString = "denied"
            granted = false
        case .authorizedWhenInUse, .authorizedAlways:
            statusString = "authorized"
            granted = true
        @unknown default:
            statusString = "unknown"
            granted = false
        }

        return [
            "type": "location",
            "displayName": "地理位置",
            "icon": "📍",
            "status": statusString,
            "granted": granted
        ]
    }

    /// 检查通知权限
    public func checkNotificationPermission(completion: @escaping ([String: Any]) -> Void) {
        guard Bundle.main.bundlePath.hasSuffix(".app") else {
            completion([
                "type": "notification",
                "displayName": "通知权限",
                "icon": "🔔",
                "status": "notDetermined",
                "granted": false
            ])
            return
        }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let statusString: String
            let granted: Bool

            switch settings.authorizationStatus {
            case .notDetermined:
                statusString = "notDetermined"
                granted = false
            case .denied:
                statusString = "denied"
                granted = false
            case .authorized, .provisional, .ephemeral:
                statusString = "authorized"
                granted = true
            @unknown default:
                statusString = "unknown"
                granted = false
            }

            completion([
                "type": "notification",
                "displayName": "通知权限",
                "icon": "🔔",
                "status": statusString,
                "granted": granted
            ])
        }
    }

    /// 检查相机权限
    public func checkCameraPermission() -> [String: Any] {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        let statusString: String
        let granted: Bool

        switch status {
        case .notDetermined:
            statusString = "notDetermined"
            granted = false
        case .restricted:
            statusString = "restricted"
            granted = false
        case .denied:
            statusString = "denied"
            granted = false
        case .authorized:
            statusString = "authorized"
            granted = true
        @unknown default:
            statusString = "unknown"
            granted = false
        }

        return [
            "type": "camera",
            "displayName": "相机权限",
            "icon": "📷",
            "status": statusString,
            "granted": granted
        ]
    }

    /// 检查麦克风权限
    public func checkMicrophonePermission() -> [String: Any] {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        let statusString: String
        let granted: Bool

        switch status {
        case .notDetermined:
            statusString = "notDetermined"
            granted = false
        case .restricted:
            statusString = "restricted"
            granted = false
        case .denied:
            statusString = "denied"
            granted = false
        case .authorized:
            statusString = "authorized"
            granted = true
        @unknown default:
            statusString = "unknown"
            granted = false
        }

        return [
            "type": "microphone",
            "displayName": "麦克风权限",
            "icon": "🎤",
            "status": statusString,
            "granted": granted
        ]
    }

    /// 检查语音识别权限
    public func checkSpeechPermission() -> [String: Any] {
        let status = SFSpeechRecognizer.authorizationStatus()
        let statusString: String
        let granted: Bool

        switch status {
        case .notDetermined:
            statusString = "notDetermined"
            granted = false
        case .restricted:
            statusString = "restricted"
            granted = false
        case .denied:
            statusString = "denied"
            granted = false
        case .authorized:
            statusString = "authorized"
            granted = true
        @unknown default:
            statusString = "unknown"
            granted = false
        }

        return [
            "type": "speech",
            "displayName": "语音识别",
            "icon": "🗣️",
            "status": statusString,
            "granted": granted
        ]
    }
}
