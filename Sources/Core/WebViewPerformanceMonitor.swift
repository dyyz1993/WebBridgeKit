//
//  WebViewPerformanceMonitor.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-15.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import UIKit

// Framework imports

/// WebView 性能监控工具
/// 提供性能测量、内存监控和对比测试功能
public class WebViewPerformanceMonitor {

    // MARK: - Singleton

    public static let shared = WebViewPerformanceMonitor()

    private init() {}

    // MARK: - 测量打开时间

    /// 测量操作耗时
    /// - Parameter operation: 要测量的操作
    /// - Returns: 耗时（毫秒）
    @discardableResult
    public func measureDuration(_ operation: () -> Void) -> TimeInterval {
        let start = CFAbsoluteTimeGetCurrent()
        operation()
        let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000

        print("⏱️ [Performance] Duration: \(String(format: "%.2f", duration))ms")

        return duration
    }

    /// 测量并记录打开浏览器的时间
    /// - Parameters:
    ///   - label: 操作标签
    ///   - operation: 要测量的操作
    public func measureOpenBrowser(label: String = "OpenBrowser", _ operation: () -> Void) {
        let start = CFAbsoluteTimeGetCurrent()
        operation()
        let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000

        print("⏱️ [Performance] \(label): \(String(format: "%.2f", duration))ms")

        // 记录到日志
        WebBridgeLogger.shared.log(
            .info,
            "[Performance] \(label): \(String(format: "%.2f", duration))ms"
        )
    }

    // MARK: - 测量内存

    /// 测量当前内存使用
    /// - Returns: 内存使用量（字节）
    public func measureMemory() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        let memory = result == KERN_SUCCESS ? info.resident_size : 0
        let memoryMB = Double(memory) / 1024 / 1024

        print("💾 [Performance] Memory usage: \(String(format: "%.2f", memoryMB))MB")

        return memory
    }

    // MARK: - 对比测试

    /// 对比测试
    /// - Parameters:
    ///   - label: 测试标签
    ///   - before: 优化前的操作
    ///   - after: 优化后的操作
    public func comparePerformance(
        label: String = "Comparison",
        before: () -> Void,
        after: () -> Void
    ) {
        print("📊 [Performance] Starting comparison test: \(label)...")

        // 测试优化前
        let memoryBefore = measureMemory()
        let timeBefore = measureDuration(before)

        // 等待一下，让系统稳定
        Thread.sleep(forTimeInterval: 0.1)

        // 测试优化后
        let memoryAfter = measureMemory()
        let timeAfter = measureDuration(after)

        // 计算改进
        let timeImprovement = timeBefore > 0 ? ((timeBefore - timeAfter) / timeBefore) * 100 : 0
        let memoryIncrease = Double(Int64(memoryAfter) - Int64(memoryBefore)) / 1024 / 1024

        print("""

        📊 [Performance] \(label) Results:
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        Time Before: \(String(format: "%.2f", timeBefore))ms
        Time After:  \(String(format: "%.2f", timeAfter))ms
        Improvement: \(String(format: "%.1f", timeImprovement))%
        Memory Increase: \(String(format: "%.2f", memoryIncrease))MB
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        """)
    }

    // MARK: - 池状态监控

    /// 打印池状态
    public func printPoolStatus() {
        let webPoolStatus = WebViewPool.shared.getPoolStatus()
        print("""

        📊 [Performance] Pool Status:
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        WebView Pool Size: \(webPoolStatus.size)
        WebView Hit Rate: \(webPoolStatus.hitRate)%
        WebView Warmed Up: \(webPoolStatus.isWarmedUp)
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        """)
    }

    // MARK: - 性能报告

    /// 生成性能报告
    /// - Returns: 性能报告字符串
    public func generateReport() -> String {
        let webPoolStatus = WebViewPool.shared.getPoolStatus()
        let memory = measureMemory()
        let memoryMB = Double(memory) / 1024 / 1024

        return """
        📊 WebView Performance Report
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        Memory Usage: \(String(format: "%.2f", memoryMB))MB
        WebView Pool Size: \(webPoolStatus.size)
        WebView Hit Rate: \(webPoolStatus.hitRate)%
        WebView Warmed Up: \(webPoolStatus.isWarmedUp)
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        """
    }
}
