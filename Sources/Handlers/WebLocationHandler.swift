//
//  WebLocationHandler.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-13.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import CoreLocation
import Foundation
import UIKit
import WebKit

// Framework imports

/// 定位处理器
/// 提供当前地理位置坐标（经纬度）和精度
public class WebLocationHandler: BaseWebNativeHandler {

    /// Location provider protocol for dependency injection (testable)
    internal protocol LocationProviding: AnyObject {
        var authorizationStatus: CLAuthorizationStatus { get }
        var locationServicesEnabled: Bool { get }
        func requestWhenInUseAuthorization()
        func requestLocation()
        func setDelegate(_ delegate: CLLocationManagerDelegate?)
    }

    /// Default CLLocationManager wrapper
    internal final class LocationManagerProvider: LocationProviding {
        private let manager = CLLocationManager()
        var authorizationStatus: CLAuthorizationStatus { CLLocationManager.authorizationStatus() }
        var locationServicesEnabled: Bool { CLLocationManager.locationServicesEnabled() }
        func requestWhenInUseAuthorization() { manager.requestWhenInUseAuthorization() }
        func requestLocation() { manager.requestLocation() }
        func setDelegate(_ delegate: CLLocationManagerDelegate?) { manager.delegate = delegate }
    }

    private let locationProvider: LocationProviding
    private var completionCallback: ((Any) -> Void)?

    init(locationProvider: LocationProviding = LocationManagerProvider()) {
        self.locationProvider = locationProvider
        super.init()
    }

    /**
     * 处理获取位置请求
     * - Parameters:
     *   - body: 请求参数字典
     *   - completion: 结果回调
     */
    public override func handle(body: [String: Any], completion: @escaping (Any) -> Void) {
        guard locationProvider.locationServicesEnabled else {
            reject(error: "Location services disabled", completion: completion)
            return
        }

        self.completionCallback = completion

        let authorizationStatus = locationProvider.authorizationStatus

        switch authorizationStatus {
        case .notDetermined:
            locationProvider.setDelegate(self)
            showLocationPermissionAlert {
                self.locationProvider.requestWhenInUseAuthorization()
            }

        case .authorizedWhenInUse, .authorizedAlways:
            getCurrentLocation()

        default:
            rejectPermissionDenied(type: .location, status: .denied, completion: completion)
        }
    }

    /**
     * 显示位置权限请求提示
     * - Parameter onAllow: 允许时的回调
     */
    private func showLocationPermissionAlert(onAllow: @escaping () -> Void) {
        runOnMainThread { [weak self] in
            guard let self = self, let topVC = self.topViewController else { return }

            let alert = UIAlertController(
                title: "位置权限",
                message: "需要您的位置信息以提供更好的服务",
                preferredStyle: .alert
            )
            alert.view.accessibilityIdentifier = "location.permissionRequest"

            alert.addAction(UIAlertAction(title: "允许", style: .default) { _ in
                onAllow()
            })
            alert.addAction(UIAlertAction(title: "拒绝", style: .cancel) { _ in
                if let completion = self.completionCallback {
                    self.rejectPermissionDenied(type: .location, status: .denied, completion: completion)
                }
            })

            topVC.present(alert, animated: true)
        }
    }

    /**
     * 开始请求当前位置
     */
    private func getCurrentLocation() {
        locationProvider.setDelegate(self)
        locationProvider.requestLocation()
    }
}

// MARK: - CLLocationManagerDelegate

extension WebLocationHandler: CLLocationManagerDelegate {
    /**
     * 处理定位权限状态变化
     */
    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        guard let completion = completionCallback else { return }

        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            // 用户授权了，获取位置
            getCurrentLocation()

        case .denied, .restricted:
            // 用户明确拒绝或权限受限
            rejectPermissionDenied(type: .location, status: .denied, completion: completion)
            completionCallback = nil

        case .notDetermined:
            // 仍然是未确定状态，等待用户选择
            break

        @unknown default:
            break
        }
    }

    /**
     * 成功获取位置后的回调
     */
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            completionCallback?([
                "success": false,
                "error": "Failed to get location"
            ])
            completionCallback = nil
            return
        }

        let result: [String: Any] = [
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "accuracy": location.horizontalAccuracy
        ]

        if let completion = completionCallback {
            resolve(result, completion: completion)
            completionCallback = nil
        }
    }

    /**
     * 获取位置失败的回调
     */
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("📍 [Location] Error: \(error.localizedDescription)")
        if let completion = completionCallback {
            reject(error: "Failed to get location: \(error.localizedDescription)", completion: completion)
            completionCallback = nil
        }
    }
}
