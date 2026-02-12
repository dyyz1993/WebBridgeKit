//
//  TestLogger.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-02-04.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation

/// 测试日志记录器
/// 用于记录 Manifest 测试用例的执行过程和结果
public class TestLogger {

    // MARK: - Properties

    private let logFileName: String
    private let logFileURL: URL
    private let dateFormatter: DateFormatter
    private var logEntries: [String] = []

    // MARK: - Static Helpers

    /// 生成时间戳字符串
    /// - Returns: 格式化的时间戳（yyyyMMdd_HHmmss）
    public static func generateTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }

    // MARK: - Initialization

    /// 创建日志记录器
    /// - Parameter testName: 测试名称（用于生成日志文件名）
    public init(testName: String) {
        // 生成日志文件名：manifest_test_{timestamp}.log
        let timestamp = TestLogger.generateTimestamp()
        self.logFileName = "manifest_test_\(timestamp).log"

        // 创建日志目录
        let logsDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TestLogs")

        try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)

        self.logFileURL = logsDirectory.appendingPathComponent(logFileName)

        // 配置日期格式化器
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "HH:mm:ss"

        // 写入日志头
        logHeader(testName: testName)
    }

    // MARK: - Public Logging Methods

    /// 记录普通信息
    /// - Parameter message: 日志消息
    public func log(_ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        let entry = "[\(timestamp)] \(message)"
        logEntries.append(entry)
        writeToLog(entry)
    }

    /// 记录成功消息
    /// - Parameter message: 日志消息
    public func logSuccess(_ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        let entry = "[\(timestamp)] ✅ \(message)"
        logEntries.append(entry)
        writeToLog(entry)
    }

    /// 记录错误消息
    /// - Parameter message: 日志消息
    public func logError(_ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        let entry = "[\(timestamp)] ❌ \(message)"
        logEntries.append(entry)
        writeToLog(entry)
    }

    /// 记录警告消息
    /// - Parameter message: 日志消息
    public func logWarning(_ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        let entry = "[\(timestamp)] ⚠️ \(message)"
        logEntries.append(entry)
        writeToLog(entry)
    }

    /// 记录信息消息
    /// - Parameter message: 日志消息
    public func logInfo(_ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        let entry = "[\(timestamp)] ℹ️ \(message)"
        logEntries.append(entry)
        writeToLog(entry)
    }

    /// 记录下载进度
    /// - Parameters:
    ///   - resource: 资源名称
    ///   - progress: 进度（0-100）
    public func logDownloadProgress(resource: String, progress: Int) {
        let timestamp = dateFormatter.string(from: Date())
        let entry = "[\(timestamp)] 📥 [\(resource)] 下载进度: \(progress)%"
        logEntries.append(entry)
        writeToLog(entry)
    }

    /// 记录缓存命中
    /// - Parameters:
    ///   - resource: 资源名称
    ///   - size: 缓存大小
    public func logCacheHit(resource: String, size: Int) {
        let timestamp = dateFormatter.string(from: Date())
        let sizeString = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
        let entry = "[\(timestamp)] 💾 [\(resource)] 缓存命中 (大小: \(sizeString))"
        logEntries.append(entry)
        writeToLog(entry)
    }

    /// 记录测试结果
    /// - Parameters:
    ///   - success: 是否成功
    ///   - duration: 耗时（秒）
    ///   - cacheSize: 缓存大小（字节）
    public func logResult(success: Bool, duration: TimeInterval, cacheSize: Int64) {
        _ = dateFormatter.string(from: Date())
        let status = success ? "成功" : "失败"
        let durationString = String(format: "%.2f秒", duration)
        let cacheSizeString = ByteCountFormatter.string(fromByteCount: cacheSize, countStyle: .file)

        let result = """
        --- 结果 ---
        状态: \(status)
        耗时: \(durationString)
        缓存大小: \(cacheSizeString)
        结束时间: \(fullTimestamp())
        """

        logEntries.append(result)
        writeToLog("\n" + result + "\n")
    }

    /// 记录测试分隔符
    public func logSeparator() {
        let separator = String(repeating: "-", count: 50)
        logEntries.append(separator)
        writeToLog(separator)
    }

    /// 记录 Manifest 详情
    /// - Parameters:
    ///   - manifest: Manifest 对象
    ///   - cacheID: 缓存 ID
    public func logManifestDetails(manifest: Manifest, cacheID: String) {
        let details = """
        --- Manifest 详情 ---
        AppID: \(manifest.appid ?? "未指定")
        名称: \(manifest.name ?? "未指定")
        版本: \(manifest.resolvedVersion)
        持久化: \(manifest.appid != nil ? "是" : "否")
        缓存 ID: \(cacheID)
        资源数量: \(manifest.resources.count)

        --- 资源列表 ---
        \(manifest.resources.map { "  • \($0.key) -> \($0.value)" }.joined(separator: "\n"))
        """

        logEntries.append(details)
        writeToLog("\n" + details + "\n")
    }

    // MARK: - File Operations

    /// 保存日志到文件
    public func save() {
        // 确保所有日志都写入磁盘
        logFooter()
        print("📝 日志已保存到: \(logFileURL.path)")
    }

    /// 获取日志文件 URL
    /// - Returns: 日志文件 URL
    public func getLogFileURL() -> URL {
        return logFileURL
    }

    /// 读取所有日志内容
    /// - Returns: 日志内容字符串
    public func readAllLogs() -> String {
        return logEntries.joined(separator: "\n")
    }

    // MARK: - Private Helper Methods

    private func logHeader(testName: String) {
        let header = """
        === Manifest 测试日志 ===
        测试用例: \(testName)
        开始时间: \(fullTimestamp())
        日志文件: \(logFileName)

        """

        writeToLog(header)
        logEntries.append(header)
    }

    private func logFooter() {
        let footer = "\n=== 日志结束 ===\n"
        writeToLog(footer)
        logEntries.append(footer)
    }

    private func writeToLog(_ message: String) {
        do {
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                let fileHandle = try FileHandle(forWritingTo: logFileURL)
                fileHandle.seekToEndOfFile()
                fileHandle.write(message.data(using: .utf8) ?? Data())
                fileHandle.closeFile()
            } else {
                try message.write(to: logFileURL, atomically: true, encoding: .utf8)
            }
        } catch {
            print("❌ 写入日志失败: \(error.localizedDescription)")
        }
    }

    private func fullTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: Date())
    }
}

// MARK: - Test Logger Extensions

/// 扩展 TestLogger 以支持批量测试
extension TestLogger {

    /// 创建批量测试日志记录器
    /// - Parameter batchName: 批次名称
    /// - Returns: 测试日志记录器
    public static func createBatchLogger(batchName: String) -> TestLogger {
        return TestLogger(testName: "Batch_\(batchName)")
    }

    /// 列出所有日志文件
    /// - Returns: 日志文件 URL 数组
    public static func listAllLogFiles() -> [URL] {
        let logsDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TestLogs")

        guard FileManager.default.fileExists(atPath: logsDirectory.path) else {
            return []
        }

        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: logsDirectory,
                includingPropertiesForKeys: nil
            )
            return files.filter { $0.pathExtension == "log" }
                .sorted { $0.lastPathComponent > $1.lastPathComponent }
        } catch {
            print("❌ 读取日志目录失败: \(error.localizedDescription)")
            return []
        }
    }

    /// 清空所有日志文件
    public static func clearAllLogs() {
        let logsDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TestLogs")

        guard FileManager.default.fileExists(atPath: logsDirectory.path) else {
            return
        }

        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: logsDirectory,
                includingPropertiesForKeys: nil
            )

            for file in files {
                try FileManager.default.removeItem(at: file)
            }

            print("🗑️ 所有测试日志已清空")
        } catch {
            print("❌ 清空日志失败: \(error.localizedDescription)")
        }
    }

    /// 读取指定日志文件内容
    /// - Parameter fileName: 日志文件名
    /// - Returns: 日志内容
    public static func readLogFile(fileName: String) -> String? {
        let logsDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TestLogs")

        let fileURL = logsDirectory.appendingPathComponent(fileName)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        do {
            return try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            print("❌ 读取日志失败: \(error.localizedDescription)")
            return nil
        }
    }
}
