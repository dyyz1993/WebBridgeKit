//
//  TestScreenshotHelper.swift
//  DemoAppUITests
//
//  Created by Claude on 2025-02-01.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import XCTest
import UIKit

/// 测试截图辅助类
/// 提供自动截图、文件保存和目录管理功能
public class TestScreenshotHelper {

    // MARK: - Properties

    /// 截图保存目录
    private static let screenshotsDirectory = "/tmp/uitest_screenshots"

    /// 是否启用截图（可通过环境变量控制）
    private static var isScreenshotEnabled: Bool {
        // 默认启用，除非明确设置 DISABLE_SCREENSHOTS=1
        return ProcessInfo.processInfo.environment["DISABLE_SCREENSHOTS"] != "1"
    }

    // MARK: - Public Methods

    /// 初始化截图目录
    public static func setupScreenshotsDirectory() {
        guard isScreenshotEnabled else { return }

        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: screenshotsDirectory) {
            try? fileManager.createDirectory(atPath: screenshotsDirectory,
                                           withIntermediateDirectories: true,
                                           attributes: nil)
            print("📁 Created screenshots directory: \(screenshotsDirectory)")
        }
    }

    /// 捕获并保存截图
    /// - Parameters:
    ///   - app: XCUIApplication 实例
    ///   - testName: 测试名称
    ///   - phase: 测试阶段 (setup, failure, teardown)
    /// - Returns: 截图文件路径
    @discardableResult
    public static func captureScreenshot(_ app: XCUIApplication,
                                        testName: String,
                                        phase: ScreenshotPhase = .setup) -> String? {
        guard isScreenshotEnabled else { return nil }

        let screenshot = app.screenshot()
        let imageData = screenshot.pngRepresentation

        // 生成文件名: timestamp-testname-phase.png
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "+", with: "-")
        let sanitizedTestName = testName.replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
        let filename = "\(timestamp)_\(sanitizedTestName)_\(phase.rawValue).png"
        let filepath = "\(screenshotsDirectory)/\(filename)"

        // 保存到文件
        try? imageData.write(to: URL(fileURLWithPath: filepath))

        // 同时添加到 Xcode 测试结果
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "\(testName)-\(phase.rawValue)"
        attachment.lifetime = .keepAlways
        XCTContext.runActivity(named: "Screenshot: \(phase.rawValue)") { _ in
            // 添加到测试报告
        }

        print("📸 Screenshot saved: \(filepath)")
        return filepath
    }

    /// 捕获失败时的截图
    /// - Parameters:
    ///   - app: XCUIApplication 实例
    ///   - testName: 测试名称
    ///   - errorMessage: 错误信息
    /// - Returns: 截图文件路径
    @discardableResult
    public static func captureFailureScreenshot(_ app: XCUIApplication,
                                               testName: String,
                                               errorMessage: String? = nil) -> String? {
        guard isScreenshotEnabled else { return nil }

        let path = captureScreenshot(app, testName: testName, phase: .failure)

        // 保存错误信息到文本文件
        if let errorMessage = errorMessage, let path = path {
            let errorLogPath = path.replacingOccurrences(of: ".png", with: ".txt")
            try? errorMessage.write(to: URL(fileURLWithPath: errorLogPath),
                                  atomically: true,
                                  encoding: .utf8)
            print("❌ Failure screenshot + error log saved: \(path)")
        }

        return path
    }

    /// 获取所有截图文件列表
    /// - Returns: 截图文件路径数组
    public static func getAllScreenshots() -> [String] {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: screenshotsDirectory) else {
            return []
        }

        guard let files = try? fileManager.contentsOfDirectory(atPath: screenshotsDirectory) else {
            return []
        }

        return files.filter { $0.hasSuffix(".png") }
            .map { "\(screenshotsDirectory)/\($0)" }
            .sorted()
    }

    /// 清除所有截图
    public static func clearAllScreenshots() {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: screenshotsDirectory) else { return }

        try? fileManager.removeItem(atPath: screenshotsDirectory)
        setupScreenshotsDirectory()
        print("🧹 All screenshots cleared")
    }

    /// 生成截图 HTML 报告
    /// - Parameter outputPath: 报告输出路径
    public static func generateScreenshotReport(outputPath: String = "/tmp/uitest_screenshots/report.html") {
        let screenshots = getAllScreenshots()

        var html = """
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>UI 测试截图报告</title>
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    background: #f5f5f7;
                    padding: 20px;
                }
                .header {
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    color: white;
                    padding: 30px;
                    border-radius: 12px;
                    margin-bottom: 20px;
                }
                .header h1 { font-size: 24px; margin-bottom: 10px; }
                .stats {
                    display: grid;
                    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
                    gap: 15px;
                    margin-bottom: 20px;
                }
                .stat-card {
                    background: white;
                    padding: 20px;
                    border-radius: 10px;
                    box-shadow: 0 2px 10px rgba(0,0,0,0.1);
                }
                .stat-card h3 { color: #666; font-size: 14px; margin-bottom: 5px; }
                .stat-card .value { font-size: 32px; font-weight: bold; color: #667eea; }
                .screenshots {
                    display: grid;
                    grid-template-columns: repeat(auto-fill, minmax(350px, 1fr));
                    gap: 20px;
                }
                .screenshot-card {
                    background: white;
                    border-radius: 12px;
                    overflow: hidden;
                    box-shadow: 0 2px 10px rgba(0,0,0,0.1);
                }
                .screenshot-card img {
                    width: 100%;
                    height: auto;
                    display: block;
                }
                .screenshot-info {
                    padding: 15px;
                }
                .screenshot-name {
                    font-weight: bold;
                    margin-bottom: 5px;
                    color: #333;
                }
                .screenshot-meta {
                    font-size: 12px;
                    color: #999;
                }
                .phase-badge {
                    display: inline-block;
                    padding: 4px 10px;
                    border-radius: 12px;
                    font-size: 11px;
                    font-weight: bold;
                    margin-right: 5px;
                }
                .phase-setup { background: #e3f2fd; color: #1976d2; }
                .phase-failure { background: #ffebee; color: #c62828; }
                .phase-teardown { background: #f3e5f5; color: #7b1fa2; }
                .phase-test { background: #e8f5e9; color: #388e3c; }
            </style>
        </head>
        <body>
            <div class="header">
                <h1>📸 UI 测试截图报告</h1>
                <p>生成时间: \(Date())</p>
                <p>截图目录: \(screenshotsDirectory)</p>
            </div>
            <div class="stats">
                <div class="stat-card">
                    <h3>总截图数</h3>
                    <div class="value">\(screenshots.count)</div>
                </div>
                <div class="stat-card">
                    <h3>失败截图</h3>
                    <div class="value">\(screenshots.filter { $0.contains("failure") }.count)</div>
                </div>
            </div>
            <div class="screenshots">
        """

        for screenshot in screenshots {
            let filename = (screenshot as NSString).lastPathComponent
            let phase = filename.contains("failure") ? "failure" :
                         filename.contains("setup") ? "setup" :
                         filename.contains("teardown") ? "teardown" : "test"

            html += """
                <div class="screenshot-card">
                    <img src="\(filename)" alt="\(filename)">
                    <div class="screenshot-info">
                        <span class="phase-badge phase-\(phase)">\(phase.uppercased())</span>
                        <div class="screenshot-name">\(filename)</div>
                        <div class="screenshot-meta">Size: \(fileSize(screenshot))</div>
                    </div>
                </div>
            """
        }

        html += """
            </div>
        </body>
        </html>
        """

        try? html.write(to: URL(fileURLWithPath: outputPath),
                        atomically: true,
                        encoding: .utf8)

        print("📊 Screenshot report generated: \(outputPath)")

        // 在浏览器中打开报告
        #if os(macOS)
        Process.execute("/usr/bin/open", arguments: [outputPath])
        #endif
    }

    // MARK: - Private Helpers

    private static func fileSize(_ path: String) -> String {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let fileSize = attributes[.size] as? UInt64 else {
            return "Unknown"
        }

        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(fileSize))
    }
}

// MARK: - Screenshot Phase

public enum ScreenshotPhase: String {
    case setup = "setup"
    case failure = "failure"
    case teardown = "teardown"
    case test = "test"
}

// MARK: - XCTestCase Extension

public extension XCTestCase {

    /// 在测试开始时截图
    func captureSetupScreenshot(app: XCUIApplication) {
        TestScreenshotHelper.captureScreenshot(app,
                                              testName: name,
                                              phase: .setup)
    }

    /// 在测试失败时截图
    func captureFailureScreenshot(app: XCUIApplication, error: String? = nil) {
        TestScreenshotHelper.captureFailureScreenshot(app,
                                                     testName: name,
                                                     errorMessage: error)
    }

    /// 在测试结束时截图
    func captureTeardownScreenshot(app: XCUIApplication) {
        TestScreenshotHelper.captureScreenshot(app,
                                              testName: name,
                                              phase: .teardown)
    }
}
