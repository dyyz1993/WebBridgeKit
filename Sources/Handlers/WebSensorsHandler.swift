//
//  WebSensorsHandler.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-14.
//

import UIKit
import WebKit
import CoreMotion

// Framework imports

/// 高频传感器数据 Handler
/// 支持：加速度计、陀螺仪、设备运动数据订阅
public class WebSensorsHandler: BaseWebNativeHandler {
    
    // MARK: - Properties
    
    private let motionManager = CMMotionManager()
    private var isAccelerometerActive = false
    private var isGyroscopeActive = false
    
    // MARK: - Handle
    
    /**
     * 处理 JS 调用
     * @param body 调用参数
     * @param completion 处理完成后的回调
     */
    public override func handle(body: [String : Any], completion: @escaping (Any) -> Void) {
        let params = body["params"] as? [String: Any] ?? body
        let action = params["action"] as? String ?? ""

        WebBridgeLogger.shared.log(.info, "[WebSensorsHandler] Handling action: \(action)")

        // 如果没有指定子操作，返回传感器可用性状态
        if action.isEmpty {
            getSensorsStatus(completion: completion)
            return
        }

        switch action {
        case "startAccelerometer":
            let interval = params["interval"] as? Double ?? 0.1 // 默认 10Hz
            startAccelerometer(interval: interval, completion: completion)

        case "stopAccelerometer":
            stopAccelerometer(completion: completion)

        case "startGyroscope":
            let interval = params["interval"] as? Double ?? 0.1
            startGyroscope(interval: interval, completion: completion)

        case "stopGyroscope":
            stopGyroscope(completion: completion)

        default:
            self.reject(error: "Unsupported action: \(action)", code: 404, completion: completion)
        }
    }

    /// 获取传感器状态
    private func getSensorsStatus(completion: @escaping (Any) -> Void) {
        self.resolve([
            "accelerometer": motionManager.isAccelerometerAvailable,
            "gyroscope": motionManager.isGyroAvailable,
            "accelerometerActive": isAccelerometerActive,
            "gyroscopeActive": isGyroscopeActive
        ], completion: completion)
    }
    
    // MARK: - Actions
    
    /**
     * 开始监听加速度计
     * @param interval 采样间隔（秒）
     * @param completion 返回结果
     */
    private func startAccelerometer(interval: Double, completion: @escaping (Any) -> Void) {
        guard motionManager.isAccelerometerAvailable else {
            self.reject(error: "Accelerometer not available", completion: completion)
            return
        }
        
        motionManager.accelerometerUpdateInterval = interval
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let data = data else { return }
            self?.notifyJS(event: "onAccelerometerChange", data: [
                "x": data.acceleration.x,
                "y": data.acceleration.y,
                "z": data.acceleration.z,
                "timestamp": data.timestamp
            ])
        }
        
        isAccelerometerActive = true
        self.resolve(["status": "started", "interval": interval], completion: completion)
    }
    
    /**
     * 停止监听加速度计
     * @param completion 返回结果
     */
    private func stopAccelerometer(completion: @escaping (Any) -> Void) {
        motionManager.stopAccelerometerUpdates()
        isAccelerometerActive = false
        self.resolve(["status": "stopped"], completion: completion)
    }
    
    /**
     * 开始监听陀螺仪
     * @param interval 采样间隔（秒）
     * @param completion 返回结果
     */
    private func startGyroscope(interval: Double, completion: @escaping (Any) -> Void) {
        guard motionManager.isGyroAvailable else {
            self.reject(error: "Gyroscope not available", completion: completion)
            return
        }
        
        motionManager.gyroUpdateInterval = interval
        motionManager.startGyroUpdates(to: .main) { [weak self] data, error in
            guard let data = data else { return }
            self?.notifyJS(event: "onGyroscopeChange", data: [
                "x": data.rotationRate.x,
                "y": data.rotationRate.y,
                "z": data.rotationRate.z,
                "timestamp": data.timestamp
            ])
        }
        
        isGyroscopeActive = true
        self.resolve(["status": "started", "interval": interval], completion: completion)
    }
    
    /**
     * 停止监听陀螺仪
     * @param completion 返回结果
     */
    private func stopGyroscope(completion: @escaping (Any) -> Void) {
        motionManager.stopGyroUpdates()
        isGyroscopeActive = false
        self.resolve(["status": "stopped"], completion: completion)
    }
    
    // MARK: - Private
    
    private func notifyJS(event: String, data: [String: Any]) {
        let script = "window.BarkBridge.receiveEvent('\(event)', \(data.jsonString ?? "{}"));"
        runOnMainThread { [weak self] in
            self?.webView?.evaluateJavaScript(script, completionHandler: nil)
        }
    }
    
    deinit {
        motionManager.stopAccelerometerUpdates()
        motionManager.stopGyroUpdates()
    }
}

fileprivate extension Dictionary {
    var jsonString: String? {
        guard let data = try? JSONSerialization.data(withJSONObject: self, options: []) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
