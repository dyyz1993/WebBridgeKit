//
//  WebBrowserViewController+Pages.swift
//  WebBridgeKit
//
//  HTML pages: welcome, JS bridge test, permissions, game, error pages
//

import UIKit

extension WebBrowserViewController {

    // MARK: - Welcome Page

    func loadWelcomePage() {
        let welcomeHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Bark 浏览器</title>
            <style>
                * { box-sizing: border-box; }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    margin: 0;
                    padding: 16px;
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    min-height: 100vh;
                }
                .container {
                    max-width: 600px;
                    margin: 0 auto;
                    background: white;
                    border-radius: 20px;
                    padding: 24px;
                    box-shadow: 0 20px 60px rgba(0,0,0,0.3);
                }
                h1 {
                    color: #667eea;
                    text-align: center;
                    margin-bottom: 8px;
                    font-size: 28px;
                }
                .subtitle {
                    text-align: center;
                    color: #666;
                    margin-bottom: 24px;
                    font-size: 14px;
                }
                .section {
                    margin: 24px 0;
                }
                .section-title {
                    font-size: 16px;
                    font-weight: 600;
                    color: #333;
                    margin-bottom: 12px;
                    border-bottom: 2px solid #667eea;
                    padding-bottom: 6px;
                }
                .link-list {
                    list-style: none;
                    padding: 0;
                    margin: 0;
                }
                .link-list li {
                    margin: 8px 0;
                }
                .link-list a {
                    display: block;
                    padding: 14px 16px;
                    background: #f7f7f7;
                    border-radius: 10px;
                    text-decoration: none;
                    color: #333;
                    transition: all 0.2s;
                    font-size: 14px;
                }
                .link-list a:active {
                    background: #667eea;
                    color: white;
                    transform: scale(0.98);
                }
                .feature-list {
                    display: grid;
                    grid-template-columns: 1fr 1fr;
                    gap: 10px;
                }
                .feature-item {
                    background: #f7f7f7;
                    padding: 16px;
                    border-radius: 10px;
                    text-align: center;
                }
                .feature-icon {
                    font-size: 28px;
                    margin-bottom: 6px;
                }
                .feature-text {
                    font-size: 13px;
                    color: #666;
                }
                .debug-btn {
                    background: #ff6b6b;
                    color: white;
                    border: none;
                    padding: 14px 24px;
                    border-radius: 10px;
                    font-size: 15px;
                    width: 100%;
                    margin-top: 16px;
                }
                #debugInfo {
                    display:none;
                    margin-top:16px;
                    padding:14px;
                    background:#f0f0f0;
                    border-radius:10px;
                    font-family:monospace;
                    font-size:11px;
                    line-height:1.6;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>🌐 Bark 浏览器</h1>
                <p class="subtitle">沉浸式全屏浏览 - 快速、简洁、智能</p>

                <div class="section">
                    <div class="section-title">📚 快速访问</div>
                    <ul class="link-list">
                        <li><a href="https://www.baidu.com">🔍 百度 - 搜索引擎</a></li>
                        <li><a href="https://github.com">🐙 GitHub - 代码托管</a></li>
                        <li><a href="https://www.apple.com">🍎 Apple - 官方网站</a></li>
                    </ul>
                </div>

                <div class="section">
                    <div class="section-title">✨ 功能特性</div>
                    <div class="feature-list">
                        <div class="feature-item">
                            <div class="feature-icon">📱</div>
                            <div class="feature-text">全屏沉浸</div>
                        </div>
                        <div class="feature-item">
                            <div class="feature-icon">⚡</div>
                            <div class="feature-text">快速加载</div>
                        </div>
                        <div class="feature-item">
                            <div class="feature-icon">🔖</div>
                            <div class="feature-text">收藏管理</div>
                        </div>
                        <div class="feature-item">
                            <div class="feature-icon">🔒</div>
                            <div class="feature-text">安全浏览</div>
                        </div>
                    </div>
                </div>

                <div class="section">
                    <div class="section-title">🔧 调试工具</div>
                    <button class="debug-btn" onclick="showDebugInfo()">查看调试信息</button>
                    <div id="debugInfo"></div>
                </div>

                <div class="section">
                    <div class="section-title">🎛️ URL 参数测试</div>
                    <ul class="link-list">
                        <li><a href="https://www.baidu.com?hideNavBar=1">隐藏导航栏打开百度</a></li>
                        <li><a href="https://www.baidu.com?hideStatusBar=1">隐藏状态栏打开百度</a></li>
                        <li><a href="https://www.baidu.com?hideNavBar=1&hideStatusBar=1">完全全屏打开百度</a></li>
                    </ul>
                </div>
            </div>

            <script>
                function showDebugInfo() {
                    const debugDiv = document.getElementById('debugInfo');
                    const info = {
                        'User Agent': navigator.userAgent.substring(0, 50) + '...',
                        'Platform': navigator.platform,
                        'Language': navigator.language,
                        'Screen': `${screen.width}x${screen.height}`,
                        'Viewport': `${window.innerWidth}x${window.innerHeight}`,
                        'Touch Support': 'ontouchstart' in window ? 'Yes' : 'No',
                        'JS Bridge': typeof window.webkit !== 'undefined' && typeof window.webkit.messageHandlers !== 'undefined' ? 'Available' : 'Not Available'
                    };

                    let html = '<strong>🔍 浏览器状态</strong><br><br>';
                    for (const [key, value] of Object.entries(info)) {
                        html += `<div style='margin:4px 0;'><strong>${key}:</strong> ${value}</div>`;
                    }
                    html += '<br><strong>✅ 页面加载完成</strong>';

                    debugDiv.innerHTML = html;
                    debugDiv.style.display = 'block';
                }
            </script>
        </body>
        </html>
        """

        webView.loadHTMLString(welcomeHTML, baseURL: Bundle.main.bundleURL)
    }

    // MARK: - JS Bridge Test Page

    func loadJSBridgeTestPage() {
        let testHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
                body { font-family: -apple-system, sans-serif; padding: 16px; background: #f5f5f5; margin: 0; }
                h1 { color: #333; margin: 0 0 16px 0; }
                .status-bar { background: white; padding: 12px; border-radius: 8px; margin-bottom: 16px; }
                .status-bar.ok { background: #d4edda; color: #155724; }
                .status-bar.error { background: #f8d7da; color: #721c24; }
                .test-section { background: white; padding: 16px; border-radius: 8px; margin-bottom: 12px; }
                .test-section h3 { margin: 0 0 12px 0; }
                .btn-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
                button { padding: 10px; border: none; border-radius: 6px; color: white; font-size: 14px; cursor: pointer; width: 100%; }
                button:active { opacity: 0.7; }
                .btn-share { background: #667eea; }
                .btn-location { background: #f093fb; }
                .btn-system { background: #4facfe; }
                .btn-network { background: #00f2fe; }
                .btn-haptic { background: #fa709a; }
                .btn-vibrate { background: #fee140; color: #333; }
                .log-section { background: #1e1e1e; color: #f0f0f0; padding: 12px; border-radius: 8px; font-family: monospace; font-size: 11px; max-height: 250px; overflow-y: auto; }
                .log-entry { padding: 4px 0; border-bottom: 1px solid #333; }
                .log-success { color: #4ade80; }
                .log-error { color: #f87171; }
                .log-info { color: #60a5fa; }
            </style>
        </head>
        <body>
            <h1>🌉 Bark JS Bridge</h1>
            <div id="statusBar" class="status-bar">检测中...</div>

            <div class="test-section">
                <h3>📤 基础功能</h3>
                <button class="btn-share" onclick="callNative('share', {text: '来自 Bark 的分享', url: 'https://github.com/Finb/Bark'})">分享</button>
                <button class="btn-location" onclick="callNative('getLocation')">获取位置</button>
            </div>

            <div class="test-section">
                <h3>📱 系统信息</h3>
                <div class="btn-grid">
                    <button class="btn-system" onclick="callNative('getSystemInfo')">系统信息</button>
                    <button class="btn-network" onclick="callNative('getNetworkInfo')">网络状态</button>
                </div>
            </div>

            <div class="test-section">
                <h3>🎨 交互反馈</h3>
                <div class="btn-grid">
                    <button class="btn-haptic" onclick="callNative('haptic')">触觉反馈</button>
                    <button class="btn-vibrate" onclick="callNative('vibrate')">震动</button>
                </div>
            </div>

            <div class="log-section">
                <div id="logContainer"></div>
            </div>

            <script>
                function addLog(type, message, data) {
                    var logContainer = document.getElementById('logContainer');
                    var time = new Date().toLocaleTimeString();
                    var logClass = type === 'success' ? 'log-success' : type === 'error' ? 'log-error' : 'log-info';
                    var div = document.createElement('div');
                    div.className = 'log-entry';
                    div.innerHTML = '[' + time + '] [' + type.toUpperCase() + '] ' + message + (data ? ' ' + JSON.stringify(data) : '');
                    logContainer.insertBefore(div, logContainer.firstChild);
                    if (logContainer.children.length > 50) {
                        logContainer.removeChild(logContainer.lastChild);
                    }
                }

                function checkBridge() {
                    var hasBridge = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.BarkBridge;
                    var statusBar = document.getElementById('statusBar');
                    if (hasBridge) {
                        statusBar.className = 'status-bar ok';
                        statusBar.textContent = '✅ JS Bridge 可用';
                        addLog('success', 'JS Bridge 检测成功');
                    } else {
                        statusBar.className = 'status-bar error';
                        statusBar.textContent = '❌ JS Bridge 不可用';
                        addLog('error', 'JS Bridge 不可用');
                    }
                    return hasBridge;
                }

                function callNative(action, params) {
                    if (!checkBridge()) return;
                    addLog('info', '调用: ' + action, params);
                    try {
                        window.webkit.messageHandlers.BarkBridge.postMessage({ action: action, params: params || {} });
                        addLog('info', '请求已发送');
                    } catch (e) {
                        addLog('error', '调用失败: ' + e.message);
                    }
                }

                window.BarkBridge = window.BarkBridge || {};
                window.BarkBridge.receiveResult = function(result) {
                    if (result.success) {
                        addLog('success', '成功', result.data);
                    } else {
                        addLog('error', '失败: ' + (result.error || 'Unknown'));
                    }
                };

                setTimeout(checkBridge, 100);
            </script>
        </body>
        </html>
        """

        webView.loadHTMLString(testHTML, baseURL: nil)
        print("🌉 [Browser] 加载 JS 桥接测试页面")
    }

    // MARK: - Permissions Page

    func loadPermissionsPage() {
        let permissionsHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
                body { font-family: -apple-system, sans-serif; padding: 16px; background: #f5f5f5; margin: 0; }
                h1 { color: #333; margin: 0 0 16px 0; }
                .summary-card { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 12px; margin-bottom: 20px; }
                .summary-title { font-size: 14px; opacity: 0.9; margin-bottom: 8px; }
                .summary-stats { display: flex; justify-content: space-around; }
                .stat-item { text-align: center; }
                .stat-value { font-size: 28px; font-weight: bold; }
                .stat-label { font-size: 11px; opacity: 0.8; }
                .permission-list { background: white; border-radius: 12px; overflow: hidden; }
                .permission-item { display: flex; align-items: center; padding: 16px; border-bottom: 1px solid #f0f0f0; }
                .permission-item:last-child { border-bottom: none; }
                .permission-icon { font-size: 28px; margin-right: 12px; }
                .permission-info { flex: 1; }
                .permission-name { font-size: 16px; font-weight: 600; color: #333; margin-bottom: 4px; }
                .permission-status { font-size: 13px; color: #666; }
                .status-badge { padding: 4px 10px; border-radius: 12px; font-size: 12px; font-weight: 600; }
                .status-authorized { background: #d4edda; color: #155724; }
                .status-denied { background: #f8d7da; color: #721c24; }
                .status-notDetermined { background: #fff3cd; color: #856404; }
                .status-limited { background: #d1ecf1; color: #0c5460; }
                .btn-settings { display: block; width: 100%; padding: 14px; background: #667eea; color: white; border: none; border-radius: 12px; font-size: 16px; font-weight: 600; margin-top: 16px; cursor: pointer; }
                .btn-settings:active { opacity: 0.8; }
                .loading { text-align: center; padding: 40px; color: #666; }
            </style>
        </head>
        <body>
            <h1>🔐 权限管理</h1>

            <div id="loading" class="loading">正在检测权限状态...</div>

            <div id="content" style="display: none;">
                <div class="summary-card">
                    <div class="summary-title">权限概览</div>
                    <div class="summary-stats">
                        <div class="stat-item">
                            <div class="stat-value" id="total">0</div>
                            <div class="stat-label">总计</div>
                        </div>
                        <div class="stat-item">
                            <div class="stat-value" id="granted">0</div>
                            <div class="stat-label">已授权</div>
                        </div>
                        <div class="stat-item">
                            <div class="stat-value" id="denied">0</div>
                            <div class="stat-label">已拒绝</div>
                        </div>
                    </div>
                </div>

                <div class="permission-list" id="permissionList"></div>

                <button class="btn-settings" onclick="openSettings()">打开系统设置</button>
            </div>

            <script>
                function callNative(action, params) {
                    try {
                        window.webkit.messageHandlers.BarkBridge.postMessage({ action: action, params: params || {} });
                    } catch (e) {
                        console.error('Native call failed:', e);
                    }
                }

                function openSettings() {
                    callNative('openSettings');
                }

                function getStatusBadge(status) {
                    switch(status) {
                        case 'authorized':
                            return '<span class="status-badge status-authorized">✅ 已授权</span>';
                        case 'denied':
                            return '<span class="status-badge status-denied">❌ 已拒绝</span>';
                        case 'notDetermined':
                            return '<span class="status-badge status-notDetermined">⚠️ 未请求</span>';
                        case 'limited':
                            return '<span class="status-badge status-limited">⚡️ 部分授权</span>';
                        default:
                            return '<span class="status-badge status-notDetermined">❓ 未知</span>';
                    }
                }

                function renderPermissions(data) {
                    var permissions = data.permissions;
                    var summary = data.summary;

                    document.getElementById('total').textContent = summary.total;
                    document.getElementById('granted').textContent = summary.granted;
                    document.getElementById('denied').textContent = summary.denied;

                    var listHTML = '';
                    for (var i = 0; i < permissions.length; i++) {
                        var perm = permissions[i];
                        listHTML += '<div class="permission-item">';
                        listHTML += '<div class="permission-icon">' + perm.icon + '</div>';
                        listHTML += '<div class="permission-info">';
                        listHTML += '<div class="permission-name">' + perm.displayName + '</div>';
                        listHTML += '<div class="permission-status">' + getStatusBadge(perm.status) + '</div>';
                        listHTML += '</div>';
                        listHTML += '</div>';
                    }

                    document.getElementById('permissionList').innerHTML = listHTML;
                    document.getElementById('loading').style.display = 'none';
                    document.getElementById('content').style.display = 'block';
                }

                setTimeout(function() {
                    callNative('getPermissionStatus');
                }, 100);

                window.BarkBridge = window.BarkBridge || {};
                window.BarkBridge.receiveResult = function(result) {
                    if (result.success && result.data && result.data.permissions) {
                        renderPermissions(result.data);
                    }
                };
            </script>
        </body>
        </html>
        """

        webView.loadHTMLString(permissionsHTML, baseURL: nil)
        print("🔐 [Browser] 加载权限管理页面")
    }

    // MARK: - Voice Jump Game

    func loadGamePage() {
        if let htmlPath = Bundle.main.path(forResource: "game", ofType: "html") {
            do {
                let htmlHTML = try String(contentsOfFile: htmlPath)
                webView.loadHTMLString(htmlHTML, baseURL: Bundle.main.bundleURL)
                print("🎮 [Browser] 加载语音控制游戏页面")
            } catch {
                print("❌ [Browser] 游戏文件加载失败: \(error)")
                showErrorPage(message: "游戏文件加载失败")
            }
        } else {
            print("❌ [Browser] 未找到游戏文件")
            showErrorPage(message: "未找到游戏文件")
        }
    }

    func showErrorPage(message: String = "加载失败") {
        let errorHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body { font-family: -apple-system, sans-serif; padding: 40px 20px; text-align: center; background: #1a1a2e; }
                h1 { color: #ff3b30; margin-bottom: 20px; }
                p { color: #aaa; font-size: 16px; }
            </style>
        </head>
        <body>
            <h1>😕 加载失败</h1>
            <p>\(message)</p>
        </body>
        </html>
        """
        webView.loadHTMLString(errorHTML, baseURL: nil)
    }
}
