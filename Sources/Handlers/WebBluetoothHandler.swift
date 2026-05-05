//
//  WebBluetoothHandler.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-14.
//

import UIKit
import WebKit
import CoreBluetooth

// Framework imports

/// 蓝牙交互 Handler
/// 支持：扫描周边设备、连接设备、监听连接状态
public class WebBluetoothHandler: BaseWebNativeHandler, CBCentralManagerDelegate {

    // MARK: - Properties

    private var centralManager: CBCentralManager?
    private var discoveredPeripherals: [String: CBPeripheral] = [:]
    private var scanCompletion: ((Any) -> Void)?

    // MARK: - Handle

    /**
     * 处理 JS 调用
     * @param body 调用参数
     * @param completion 处理完成后的回调
     */
    public override func handle(body: [String: Any], completion: @escaping (Any) -> Void) {
        let params = body["params"] as? [String: Any] ?? body
        let action = params["action"] as? String ?? ""

        WebBridgeLogger.shared.log(.info, "[WebBluetoothHandler] Handling action: \(action)")

        if centralManager == nil {
            centralManager = CBCentralManager(delegate: self, queue: nil)
        }

        // 如果没有指定子操作，返回蓝牙状态
        if action.isEmpty {
            getBluetoothStatus(completion: completion)
            return
        }

        switch action {
        case "startScan":
            startScan(completion: completion)

        case "stopScan":
            stopScan(completion: completion)

        default:
            self.reject(error: "Unsupported action: \(action)", code: 404, completion: completion)
        }
    }

    /// 获取蓝牙状态
    private func getBluetoothStatus(completion: @escaping (Any) -> Void) {
        guard let central = centralManager else {
            self.resolve(["available": false, "state": "unavailable"], completion: completion)
            return
        }

        let stateString: String
        switch central.state {
        case .poweredOn: stateString = "poweredOn"
        case .poweredOff: stateString = "poweredOff"
        case .unauthorized: stateString = "unauthorized"
        case .unknown: stateString = "unknown"
        case .resetting: stateString = "resetting"
        case .unsupported: stateString = "unsupported"
        @unknown default: stateString = "unknown"
        }

        self.resolve([
            "available": central.state == .poweredOn,
            "state": stateString
        ], completion: completion)
    }

    // MARK: - Actions

    private func startScan(completion: @escaping (Any) -> Void) {
        guard let central = centralManager else {
            self.reject(error: "Bluetooth manager not initialized", completion: completion)
            return
        }

        if central.state == .poweredOn {
            discoveredPeripherals.removeAll()
            central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
            WebBridgeLogger.shared.log(.info, "[WebBluetoothHandler] Scanning started")
            self.resolve(["status": "scanning"], completion: completion)
        } else if central.state == .unknown || central.state == .resetting {
            // 还在初始化，等待一会儿再重试
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.startScan(completion: completion)
            }
        } else {
            self.reject(error: "Bluetooth is not powered on (State: \(central.state.rawValue))", completion: completion)
        }
    }

    private func stopScan(completion: @escaping (Any) -> Void) {
        centralManager?.stopScan()
        WebBridgeLogger.shared.log(.info, "[WebBluetoothHandler] Scanning stopped")
        self.resolve(["status": "stopped"], completion: completion)
    }

    // MARK: - CBCentralManagerDelegate

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        WebBridgeLogger.shared.log(.info, "[WebBluetoothHandler] State updated: \(central.state.rawValue)")
        sendEventToJS(event: "onBluetoothStateChange", data: ["state": central.state.rawValue])
    }

    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let deviceId = peripheral.identifier.uuidString

        // 即使已发现，也更新一下 RSSI 和名称（可能有变化）
        discoveredPeripherals[deviceId] = peripheral

        let deviceData: [String: Any] = [
            "id": deviceId,
            "name": peripheral.name ?? "Unknown Device",
            "rssi": RSSI,
            "localName": advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? ""
        ]

        WebBridgeLogger.shared.log(.info, "[WebBluetoothHandler] Discovered device: \(peripheral.name ?? "Unknown") (\(deviceId))")
        sendEventToJS(event: "onBluetoothDeviceFound", data: deviceData)
    }

    // MARK: - Private

    private func notifyJS(event: String, data: [String: Any]) {
        sendEventToJS(event: event, data: data)
    }
}

fileprivate extension Dictionary {
    var jsonString: String? {
        guard let data = try? JSONSerialization.data(withJSONObject: self, options: []) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
