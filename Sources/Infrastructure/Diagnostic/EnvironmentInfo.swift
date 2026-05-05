//
//  EnvironmentInfo.swift
//  WebBridgeKit
//

import Foundation
import UIKit

/// 设备和环境信息快照
public struct EnvironmentInfo {

    /// App 信息
    public let appVersion: String
    public let buildNumber: String
    public let bundleIdentifier: String
    public let appName: String

    /// 设备信息
    public let deviceModel: String
    public let deviceName: String
    public let systemName: String
    public let systemVersion: String
    public let screenBounds: CGRect
    public let screenScale: CGFloat

    /// 资源信息
    public let physicalMemory: UInt64
    public let freeMemory: UInt64
    public let totalDiskSpace: UInt64
    public let freeDiskSpace: UInt64

    /// 网络信息
    public let networkType: String
    public let isConnected: Bool

    /// 采集时间
    public let capturedAt: Date

    public init() {
        let bundle = Bundle.main
        let processInfo = ProcessInfo.processInfo
        let device = UIDevice.current

        self.appVersion = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        self.buildNumber = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        self.bundleIdentifier = bundle.bundleIdentifier ?? "unknown"
        self.appName = bundle.infoDictionary?["CFBundleName"] as? String ?? "unknown"

        self.deviceModel = Self.getDeviceModel()
        self.deviceName = device.name
        self.systemName = device.systemName
        self.systemVersion = device.systemVersion
        self.screenBounds = UIScreen.main.bounds
        self.screenScale = UIScreen.main.scale

        self.physicalMemory = processInfo.physicalMemory

        var freeMemory: UInt64 = 0
        var pageSize: vm_size_t = 0
        let hostPort: mach_port_t = mach_host_self()
        var hostSize: mach_msg_type_number_t = mach_msg_type_number_t(MemoryLayout<vm_statistics>.size / MemoryLayout<integer_t>.size)
        var vmInfo = vm_statistics()
        host_page_size(hostPort, &pageSize)
        let kernReturn: kern_return_t = withUnsafeMutablePointer(to: &vmInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(hostSize)) {
                host_statistics(hostPort, HOST_VM_INFO, $0, &hostSize)
            }
        }
        if kernReturn == KERN_SUCCESS {
            freeMemory = UInt64(vmInfo.free_count) * UInt64(pageSize)
        }
        self.freeMemory = freeMemory

        let fileURL = URL(fileURLWithPath: NSHomeDirectory())
        let values = try? fileURL.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey])
        self.totalDiskSpace = UInt64(values?.volumeTotalCapacity ?? 0)
        self.freeDiskSpace = UInt64(values?.volumeAvailableCapacityForImportantUsage ?? 0)

        self.networkType = Self.getCurrentNetworkType()
        self.isConnected = true
        self.capturedAt = Date()
    }

    // MARK: - Formatted Output

    /// 可读的摘要信息
    public var summary: String {
        """
        📱 \(appName) v\(appVersion) (\(buildNumber))
        📱 \(deviceModel) / \(systemName) \(systemVersion)
        📺 \(String(format: "%.0f×%.0f @%.0fx", screenBounds.width, screenBounds.height, screenScale))
        💾 Memory: \(formatBytes(freeMemory)) / \(formatBytes(physicalMemory))
        💽 Disk: \(formatBytes(freeDiskSpace)) / \(formatBytes(totalDiskSpace))
        🌐 Network: \(networkType) (\(isConnected ? "connected" : "disconnected"))
        """
    }

    /// 完整的调试信息（可复制）
    public var debugString: String {
        """
        === Environment Info ===
        App: \(appName)
        Version: \(appVersion) (\(buildNumber))
        Bundle: \(bundleIdentifier)
        Device: \(deviceModel)
        OS: \(systemName) \(systemVersion)
        Screen: \(String(format: "%.0f×%.0f @%.0fx", screenBounds.width, screenBounds.height, screenScale))
        Physical Memory: \(formatBytes(physicalMemory))
        Free Memory: \(formatBytes(freeMemory))
        Total Disk: \(formatBytes(totalDiskSpace))
        Free Disk: \(formatBytes(freeDiskSpace))
        Network: \(networkType) (\(isConnected ? "connected" : "disconnected"))
        Captured: \(ISO8601DateFormatter().string(from: capturedAt))
        ========================
        """
    }

    /// JSON 字典
    public var jsonDict: [String: Any] {
        [
            "app_version": appVersion,
            "build_number": buildNumber,
            "bundle_id": bundleIdentifier,
            "device_model": deviceModel,
            "os_version": "\(systemName) \(systemVersion)",
            "screen": "\(Int(screenBounds.width))×\(Int(screenBounds.height)) @\(Int(screenScale))x",
            "physical_memory": physicalMemory,
            "free_memory": freeMemory,
            "total_disk": totalDiskSpace,
            "free_disk": freeDiskSpace,
            "network_type": networkType,
            "connected": isConnected,
            "captured_at": ISO8601DateFormatter().string(from: capturedAt)
        ]
    }

    // MARK: - Helpers

    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private static func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
    }

    private static func getCurrentNetworkType() -> String {
        // Basic network type detection
        let reachability = SCNetworkReachabilityCreateWithName(nil, "www.apple.com")
        var flags = SCNetworkReachabilityFlags()
        if let reachability = reachability,
           SCNetworkReachabilityGetFlags(reachability, &flags) {
            if flags.contains(.isWWAN) {
                return "Cellular"
            } else if flags.contains(.reachable) {
                return "WiFi"
            }
        }
        return "Unknown"
    }
}

// Missing import for SCNetworkReachability
import SystemConfiguration
