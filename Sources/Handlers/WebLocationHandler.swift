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

    private let locationManager = CLLocationManager()
    private var completionCallback: ((Any) -> Void)?

    /**
     * 处理获取位置请求
     * - Parameters:
     *   - body: 请求参数字典
     *   - completion: 结果回调
     */
    public override func handle(body: [String: Any], completion: @escaping (Any) -> Void) {
        guard CLLocationManager.locationServicesEnabled() else {
            reject(error: "Location services disabled", completion: completion)
            return
        }

        self.completionCallback = completion

        let authorizationStatus = CLLocationManager.authorizationStatus()

        switch authorizationStatus {
        case .notDetermined:
            // 首次请求权限 - 设置代理并请求，等待 didChangeAuthorization 回调
            locationManager.delegate = self
            locationManager.requestWhenInUseAuthorization()
            // 注意：不在这里返回结果，等待 didChangeAuthorization 回调

        case .authorizedWhenInUse, .authorizedAlways:
            // 已授权，直接获取位置
            getCurrentLocation()

        default:
            // 已明确拒绝或受限，返回权限引导
            rejectPermissionDenied(type: .location, status: .denied, completion: completion)
        }
    }

    /**
     * 开始请求当前位置
     */
    private func getCurrentLocation() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.requestLocation()
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
