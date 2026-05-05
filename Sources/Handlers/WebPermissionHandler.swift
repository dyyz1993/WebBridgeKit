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
        case location
        case notification
        case camera
        case microphone
    }

    // Properties for location permission handling
    private var locationManager: CLLocationManager?
    private var tempCompletion: ((Any) -> Void)?

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
        runOnMainThread { [weak self] in
            guard let self = self, let topVC = self.topViewController else {
                self?.reject(error: "No view controller available", completion: completion)
                return
            }

            let locationManager = CLLocationManager()

            guard CLLocationManager.locationServicesEnabled() else {
                self.reject(error: "Location services disabled", completion: completion)
                return
            }

            let status = CLLocationManager.authorizationStatus()

            if status == .notDetermined {
                // 显示权限请求提示
                let alert = UIAlertController(
                    title: "位置权限",
                    message: "需要位置权限以继续",
                    preferredStyle: .alert
                )
                alert.view.accessibilityIdentifier = "permission.alertDialog"

                alert.addAction(UIAlertAction(title: "允许", style: .default) { _ in
                    // 请求系统权限
                    self.locationManager = CLLocationManager()
                    self.locationManager?.delegate = self
                    self.tempCompletion = completion
                    self.locationManager?.requestWhenInUseAuthorization()
                })
                alert.addAction(UIAlertAction(title: "拒绝", style: .cancel) { _ in
                    self.resolve(["granted": false, "status": status.rawValue], completion: completion)
                })

                topVC.present(alert, animated: true)
            } else {
                let granted = status == .authorizedWhenInUse || status == .authorizedAlways
                self.resolve(["granted": granted, "status": status.rawValue], completion: completion)
            }
        }
    }

    // MARK: - Notification Permission

    private func requestNotificationPermission(completion: @escaping (Any) -> Void) {
        runOnMainThread { [weak self] in
            guard let self = self, let topVC = self.topViewController else {
                self?.reject(error: "No view controller available", completion: completion)
                return
            }

            let alert = UIAlertController(
                title: "通知权限",
                message: "需要通知权限以发送消息提醒",
                preferredStyle: .alert
            )
            alert.view.accessibilityIdentifier = "permission.alertDialog"

            alert.addAction(UIAlertAction(title: "允许", style: .default) { _ in
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    if let error = error {
                        self.reject(error: error.localizedDescription, completion: completion)
                    } else {
                        self.resolve(["granted": granted], completion: completion)
                    }
                }
            })
            alert.addAction(UIAlertAction(title: "拒绝", style: .cancel) { _ in
                self.resolve(["granted": false], completion: completion)
            })

            topVC.present(alert, animated: true)
        }
    }

    // MARK: - AV Permission (Camera/Microphone)

    private func requestAVPermission(type: AVMediaType, completion: @escaping (Any) -> Void) {
        runOnMainThread { [weak self] in
            guard let self = self, let topVC = self.topViewController else {
                self?.reject(error: "No view controller available", completion: completion)
                return
            }

            let mediaType = type == AVMediaType.video ? "相机" : "麦克风"
            let status = AVCaptureDevice.authorizationStatus(for: type)

            if status == .notDetermined {
                let alert = UIAlertController(
                    title: "\(mediaType)权限",
                    message: "需要\(mediaType)权限以继续",
                    preferredStyle: .alert
                )
                alert.view.accessibilityIdentifier = "permission.alertDialog"

                alert.addAction(UIAlertAction(title: "允许", style: .default) { _ in
                    AVCaptureDevice.requestAccess(for: type) { granted in
                        self.resolve(["granted": granted, "status": AVCaptureDevice.authorizationStatus(for: type).rawValue], completion: completion)
                    }
                })
                alert.addAction(UIAlertAction(title: "拒绝", style: .cancel) { _ in
                    self.resolve(["granted": false, "status": status.rawValue], completion: completion)
                })

                topVC.present(alert, animated: true)
            } else {
                let granted = status == .authorized
                self.resolve(["granted": granted, "status": status.rawValue], completion: completion)
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension WebPermissionHandler: CLLocationManagerDelegate {
    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        guard let completion = tempCompletion else { return }

        let granted = status == .authorizedWhenInUse || status == .authorizedAlways
        resolve(["granted": granted, "status": status.rawValue], completion: completion)

        tempCompletion = nil
        locationManager = nil
    }
}
