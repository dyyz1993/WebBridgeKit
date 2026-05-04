//
//  DebugErrorPageManager.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-02-13.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation

/// 调试错误页面管理器
/// 生成原生的 HTML 错误页面，包含完整的错误信息和调试功能
public class DebugErrorPageManager {

    // MARK: - Singleton

    public static let shared = DebugErrorPageManager()

    // MARK: - Error Page Generation

    /// 生成调试错误页面
    /// - Parameters:
    ///   - url: 请求的 URL
    ///   - error: 错误对象
    ///   - debugInfo: 调试信息（可选）
    /// - Returns: HTML 字符串
    public func generateErrorPage(
        url: URL,
        error: Error,
        debugInfo: [String: Any]? = nil
    ) -> String {

        // 构建错误页面 HTML
        var html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>WebBridge 加载失败</title>
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    min-height: 100vh;
                    margin: 0;
                    padding: 20px;
                    color: #333;
                }
                .container {
                    max-width: 800px;
                    margin: 40px auto;
                    background: white;
                    border-radius: 12px;
                    padding: 30px;
                    box-shadow: 0 10px 30px rgba(0,0,0,0.2);
                }
                h1 { color: #c53030; font-size: 24px; margin-bottom: 10px; }
                .subtitle { color: #666; font-size: 16px; margin-bottom: 20px; }
                .icon { font-size: 48px; margin-bottom: 10px; }
                .info-box {
                    background: #f8f9fa;
                    border-left: 4px solid #2196F3;
                    padding: 15px;
                    border-radius: 8px;
                    margin-bottom: 20px;
                }
                .error-code {
                    background: #edf2f7;
                    padding: 3px 6px;
                    border-radius: 4px;
                    font-family: "SFMono-Regular", Consolas, monospace;
                    font-size: 13px;
                    color: #e91e63;
                }
                .btn {
                    display: inline-block;
                    background: #4a5568;
                    color: white;
                    padding: 8px 16px;
                    border-radius: 6px;
                    text-decoration: none;
                    margin-top: 15px;
                    font-size: 14px;
                }
                .btn:hover { background: #2d3748; }
                .btn-secondary {
                    background: #6c757d;
                    color: white;
                    padding: 8px 16px;
                    border-radius: 6px;
                    text-decoration: none;
                    margin-top: 10px;
                    font-size: 14px;
                }
                code {
                    background: #f5f5f5;
                    padding: 2px 4px;
                    border-radius: 4px;
                    font-family: "SFMono-Regular", Consolas, monospace;
                    font-size: 12px;
                    color: #1a202c;
                    overflow-x: auto;
                }
                .footer {
                    margin-top: 30px;
                    font-size: 14px;
                    color: #4a5568;
                    border-top: 1px solid #edf2f7;
                    padding-top: 20px;
                }
                .copy-btn {
                    background: #4CAF50;
                    color: white;
                    padding: 6px 12px;
                    border-radius: 4px;
                    margin-left: 10px;
                    text-decoration: none;
                    font-size: 13px;
                }
                .debug-section {
                    margin-top: 20px;
                    background: #f9f9f9;
                    border: 1px solid #e0e0e0;
                    border-radius: 8px;
                    padding: 15px;
                }
                .debug-item {
                    padding: 8px 0;
                    border-bottom: 1px solid #e0e0e0;
                }
        """

        // 添加错误信息
        let errorTitle = error.localizedDescription
        let errorMessage = error.localizedDescription

        html += """
            <div class="container">
                <div class="info-box">
                    <h1>⚠️ 加载失败</h1>
                    <div class="subtitle">无法加载页面</div>
                </div>

                <div class="info-box">
                    <h2>📋 请求地址</h2>
                    <div class="error-code">\(url.absoluteString)</div>
                </div>

                <div class="info-box">
                    <h2>💬 错误原因</h2>
                    <div class="error-code">\(errorMessage)</div>
                </div>
        """

        // 添加调试信息（如果有）
        if let debugInfo = debugInfo {
            html += """
                <div class="debug-section">
                    <h3>🔍 调试信息</h3>
                """

            for (key, value) in debugInfo {
                html += """
                    <div class="debug-item">
                        <span class="label">\(key):</span>
                        <span class="value">\(value)</span>
                    </div>
                """
            }

            html += """
                </div>
            """
        }

        // 添加操作按钮
        html += """
                <div style="text-align: center;">
                    <button class="btn" onclick="window.location.reload()">重新加载</button>
                    <button class="btn btn-secondary" onclick="navigator.clipboard.writeText('\(url.absoluteString)')">复制 URL</button>
                </div>
            """

        // 结束标签
        html += """
                <div class="footer">
                    <p>如果问题持续存在，请联系技术支持。</p>
                </div>
            </body>
        </html>
        """

        return html
    }

    // MARK: - Helper Methods

    /// 获取堆栈信息的字符串表示
    private func getStackTraceString(_ error: Error) -> String {
        let stackTrace = error.localizedDescription
        return stackTrace.components(separatedBy: .newlines).prefix(10).joined(separator: "\n    $")
    }

    /// URL 编码（用于在 data URL 中传递）
    private func encodeURL(_ url: URL) -> String {
        return (url.absoluteString ?? "").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    }
}
