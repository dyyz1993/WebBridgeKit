/**
 * WebBridge Debug Script
 *
 * 当开启 debugMode 时，此脚本会自动注入到页面
 * 提供错误检测、堆栈追踪、网络请求监听、复制等功能
 */

(function() {
    'use strict';

    // ==================== 配置 ====================

    const CONFIG = {
        // 检测间隔（毫秒）
        checkInterval: 500,

        // 最大堆栈深度
        maxStackTrace: 20,

        // 是否启用详细日志
        verboseLogging: true,

        // 主题（light/dark）
        theme: 'light'
    };

    // ==================== 状态 ====================

    const state = {
        hasError: false,
        errorTimestamp: null,
        stackTrace: [],
        networkRequests: [],
        loadStartTime: Date.now(),
        isReady: false
    };

    // ==================== 工具函数 ====================

    const utils = {
        // 格式化时间戳
        formatTime: function(timestamp) {
            if (!timestamp) return '未知';
            const date = new Date(timestamp);
            return date.toLocaleTimeString('zh-CN');
        },

        // 格式化字节数
        formatBytes: function(bytes) {
            if (bytes < 1024) return bytes + ' B';
            if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(2) + ' KB';
            if (bytes < 1024 * 1024 * 1024) return (bytes / (1024 * 1024)).toFixed(2) + ' MB';
            return (bytes / (1024 * 1024 * 1024)).toFixed(2) + ' GB';
        },

        // 安全的 HTML 转义
        escapeHTML: function(str) {
            const div = document.createElement('div');
            div.textContent = str;
            return div.innerHTML;
        },

        // 获取堆栈信息
        getStackTrace: function() {
            const stack = state.stackTrace.slice(-CONFIG.maxStackTrace);
            if (stack.length === 0) return '无堆栈信息';
            return stack.join(' → ');
        },

        // 清空堆栈
        clearStackTrace: function() {
            state.stackTrace = [];
            this.updateUI();
        },

        // 添加堆栈项
        pushStackTrace: function(message) {
            state.stackTrace.push({
                message: message,
                time: new Date().toISOString(),
                type: 'log'
            });
            this.updateUI();
            this.checkErrorState();
        },

        // 检查错误状态
        checkErrorState: function() {
            const hasError = state.stackTrace.some(item =>
                item.type === 'error' || item.message.includes('错误') || item.message.includes('失败')
            );
            if (hasError && !state.hasError) {
                state.hasError = true;
                state.errorTimestamp = new Date().toISOString();
                this.onPageLoadError();
            } else if (!hasError && state.hasError) {
                state.hasError = false;
                this.hideErrorMessage();
            }
        },

        // 页面加载失败处理
        onPageLoadError: function() {
            const duration = Date.now() - state.loadStartTime;
            const durationStr = (duration / 1000).toFixed(2) + 's';

            console.error('%c[WebBridge Debug] 页面加载失败', 'color: #c53030');
            console.error('%c[WebBridge Debug] 加载耗时: ' + durationStr, 'color: #666');

            this.pushStackTrace('页面加载失败');
            this.showErrorMessage();
            this.checkErrorState();

            // 自动发送到 Native
            if (window.webkit?.messageHandlers?.WebBridgeDebug) {
                window.webkit.messageHandlers.WebBridgeDebug.postMessage({
                    type: 'pageLoadError',
                    url: window.location.href,
                    duration: durationStr,
                    stackTrace: this.getStackTraceString()
                });
            }
        },

        // ==================== 网络监听 ====================

        setupNetworkMonitoring: function() {
            // 拦截 fetch
            const originalFetch = window.fetch;
            window.fetch = function(...args) {
                const url = args[0];
                const startTime = Date.now();

                state.networkRequests.push({
                    url: url,
                    method: args[1] || 'GET',
                    startTime: startTime,
                    timestamp: new Date().toISOString()
                });

                if (CONFIG.verboseLogging) {
                    console.log('%c[Network] → ' + args[1] || 'GET', 'color: #2196F3', url);
                }

                return originalFetch.apply(this, args).then(response => {
                    const duration = Date.now() - startTime;
                    const durationStr = (duration / 1000).toFixed(2) + 's';

                    if (CONFIG.verboseLogging) {
                        const statusColor = response.ok ? '#4CAF50' : '#f44336';
                        console.log('%c[Network] ← ' + durationStr + ' - ' + (response.ok ? '200' : response.status), 'color: statusColor);
                        console.log('%c[Network] Size: ' + utils.formatBytes(response.headers.get('content-length') || 0), 'color: #666');
                    }

                    return response;
                }).catch(error => {
                    this.pushStackTrace('网络请求失败: ' + error.message);
                    this.checkErrorState();
                });
            };

            // 拦截 XMLHttpRequest
            const originalXHR = window.XMLHttpRequest;
            const XHR = function() {
                const xhr = new originalXHR();
                const originalOpen = xhr.open;

                xhr.open = function(method, url, async) {
                    const startTime = Date.now();

                    state.networkRequests.push({
                        url: url,
                        method: method,
                        startTime: startTime,
                        timestamp: new Date().toISOString()
                    });

                    if (CONFIG.verboseLogging) {
                        console.log('%c[Network] XHR → ' + method, 'color: #2196F3', url);
                    }

                    return originalOpen.call(this, method, url, async);
                };

                const originalSend = xhr.send;
                xhr.send = function(...args) {
                    return originalSend.apply(this, args);
                };

                xhr.addEventListener('load', function() {
                    const duration = Date.now() - startTime;
                    const durationStr = (duration / 1000).toFixed(2) + 's';

                    if (CONFIG.verboseLogging) {
                        const statusColor = xhr.status >= 200 && xhr.status < 300 ? '#4CAF50' : '#f44336';
                        console.log('%c[Network] XHR ← ' + durationStr + ' - ' + xhr.status, 'color: statusColor);
                    }

                    // 成功完成
                    if (xhr.status >= 200 && xhr.status < 300) {
                        state.networkRequests = state.networkRequests.filter(r => r.url !== url);
                    }
                });

                const originalOnError = xhr.onerror;
                xhr.onerror = function(error) {
                    this.pushStackTrace('XHR 错误: ' + error.message);
                    this.checkErrorState();
                };

                window.XMLHttpRequest = XHR;
            };

        // ==================== UI 控制 ====================

        // 显示错误信息面板
        showErrorMessage: function() {
            const errorPanel = document.getElementById('wb-debug-error-panel');
            if (errorPanel) {
                errorPanel.style.display = 'block';
            }
        },

        // 隐藏错误信息面板
        hideErrorMessage: function() {
            const errorPanel = document.getElementById('wb-debug-error-panel');
            if (errorPanel) {
                errorPanel.style.display = 'none';
            }
        },

        // 更新 UI
        updateUI: function() {
            const stackList = document.getElementById('wb-debug-stack');
            const requestList = document.getElementById('wb-debug-requests');
            const statusIndicator = document.getElementById('wb-debug-status');

            if (stackList) {
                stackList.innerHTML = state.stackTrace.map(item => `
                    <div class="debug-item ${item.type === 'error' ? 'error' : ''}">
                        <span class="time">${utils.formatTime(item.time)}</span>
                        <span class="label">${utils.escapeHTML(item.message)}</span>
                    </div>
                `).join('');

                if (state.stackTrace.length > 0) {
                    stackList.style.display = 'block';
                } else {
                    stackList.innerHTML = '<div style="color: #999; padding: 20px; text-align: center;">暂无堆栈信息</div>';
                }
            }

            if (requestList) {
                requestList.innerHTML = state.networkRequests.map(req => `
                    <div class="debug-item">
                        <span class="time">${utils.formatTime(req.timestamp)}</span>
                        <span class="label">${req.method}</span>
                        <span class="value">${utils.escapeHTML(req.url)}</span>
                    </div>
                `).join('');
            }

            // 状态指示器
            if (state.hasError) {
                if (statusIndicator) {
                    statusIndicator.textContent = '❌ 错误';
                    statusIndicator.style.color = '#f44336';
                }
            } else if (state.isReady) {
                if (statusIndicator) {
                    statusIndicator.textContent = '✅ 正常';
                    statusIndicator.style.color = '#4CAF50';
                }
            }
        },

        // 复制文本到剪贴板
        copyToClipboard: function(text) {
            if (navigator.clipboard && navigator.clipboard.writeText) {
                navigator.clipboard.writeText(text).then(() => {
                    console.log('%c[WebBridge Debug] 已复制: ' + text, 'color: #4CAF50');
                    this.pushStackTrace('复制成功: ' + text);
                }).catch(err => {
                    console.error('%c[WebBridge Debug] 复制失败: ' + err, 'color: #f44336');
                });
            } else {
                // 降级方案
                const textArea = document.createElement('textarea');
                textArea.value = text;
                textArea.style.position = 'fixed';
                textArea.style.top = '-9999px';
                textArea.style.left = '0';
                textArea.select();
                document.execCommand('copy');
                document.body.removeChild(textArea);
                this.pushStackTrace('已复制到剪贴板（降级）');
            }
        },

        // ==================== Native 消息处理 ====================

        handleNativeMessage: function(message) {
            if (CONFIG.verboseLogging) {
                console.log('%c[WebBridge Debug] 收到 Native 消息', 'color: #2196F3');
                console.log('消息类型:', message.type);
                console.log('消息内容:', message);
            }

            switch (message.type) {
                case 'setDebugInfo':
                    // 设置调试信息
                    if (message.debugInfo) {
                        state.debugInfo = message.debugInfo;
                        this.updateUI();
                        this.pushStackTrace('调试信息已更新');
                    }
                    break;

                case 'clearError':
                    // 清除错误状态
                    this.clearStackTrace();
                    this.hideErrorMessage();
                    this.checkErrorState();
                    break;

                case 'copyToClipboard':
                    // 复制到剪贴板
                    const text = message.text || '';
                    this.copyToClipboard(text);
                    break;
            }
        },

        // ==================== 初始化 ====================

        init: function() {
            console.log('%c[WebBridge Debug] 调试脚本已加载', 'color: #4CAF50');
            console.log('%c[WebBridge Debug] 版本: 1.0.0', 'color: #666');
            console.log('%c[WebBridge Debug] 配置:', 'color: #2196F3');
            console.log('  检查间隔: ' + CONFIG.checkInterval + 'ms');
            console.log('  最大堆栈: ' + CONFIG.maxStackTrace);
            console.log('  详细日志: ' + (CONFIG.verboseLogging ? '开启' : '关闭'));

            // 创建调试 UI（延迟执行，确保 DOM 就绪）
            setTimeout(() => {
                this.createDebugUI();
                this.startErrorCheck();
            }, 100);

            // 监听页面加载完成
            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', () => {
                    state.isReady = true;
                    this.updateUI();
                    console.log('%c[WebBridge Debug] 页面就绪', 'color: #4CAF50');
                }, false);
            } else {
                state.isReady = true;
            }

            // 注册消息处理器
            if (window.webkit?.messageHandlers) {
                window.webkit.messageHandlers.WebBridgeDebug = this.handleNativeMessage.bind(this);
            } else if (window.webkit) {
                window.webkit.messageHandlers = {};
                window.webkit.messageHandlers.WebBridgeDebug = this.handleNativeMessage.bind(this);
            }

            console.log('%c[WebBridge Debug] 初始化完成', 'color: #4CAF50');
        },

        // ==================== UI 创建 ====================

        createDebugUI: function() {
            // 检查是否已存在
            if (document.getElementById('wb-debug-panel')) {
                console.log('%c[WebBridge Debug] 调试面板已存在', 'color: #999');
                return;
            }

            // 创建主面板
            const panel = document.createElement('div');
            panel.id = 'wb-debug-panel';
            panel.style.cssText = `
                position: fixed;
                top: 10px;
                right: 10px;
                width: 350px;
                max-height: 80vh;
                background: rgba(0, 0, 0, 0.95);
                backdrop-filter: blur(5px);
                border-radius: 8px;
                box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
                font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                z-index: 99999;
                overflow: hidden;
                transition: opacity 0.3s ease;
            `;

            document.body.appendChild(panel);

            // 创建面板内容
            const content = document.createElement('div');
            content.style.cssText = `
                height: 100%;
                overflow-y: auto;
                padding: 15px;
            `;

            // 标题栏
            const header = document.createElement('div');
            header.style.cssText = `
                display: flex;
                justify-content: space-between;
                align-items: center;
                padding-bottom: 10px;
                border-bottom: 1px solid rgba(0, 0, 0, 0.1);
            `;
            header.innerHTML = `
                <span style="font-weight: 600; color: #333;">🔍 WebBridge 调试面板</span>
                <button onclick="window.WebBridgeDebug.togglePanel()" style="
                    background: rgba(255, 255, 255, 0.1);
                    border: 1px solid rgba(0, 0, 0, 0.2);
                    border-radius: 4px;
                    padding: 2px 8px;
                    font-size: 12px;
                    cursor: pointer;
                ">_</button>
            `;
            content.appendChild(header);

            // 状态指示器
            const statusDiv = document.createElement('div');
            statusDiv.id = 'wb-debug-status';
            statusDiv.style.cssText = `
                padding: 8px 12px;
                background: rgba(0, 0, 0, 0.05);
                border-radius: 4px;
                font-size: 12px;
                text-align: center;
            `;
            statusDiv.textContent = '⏳ 等待页面加载...';
            content.appendChild(statusDiv);

            // 堆栈信息
            const stackHeader = document.createElement('div');
            stackHeader.style.cssText = `
                font-size: 13px;
                font-weight: 600;
                color: #666;
                margin-top: 15px;
                padding-bottom: 5px;
            `;
            stackHeader.textContent = '调用堆栈';

            const stackList = document.createElement('div');
            stackList.id = 'wb-debug-stack';
            stackList.style.cssText = `
                max-height: 200px;
                overflow-y: auto;
                font-size: 11px;
                line-height: 1.6;
            `;
            stackList.innerHTML = '<div style="color: #999; padding: 20px; text-align: center;">暂无堆栈信息</div>';
            content.appendChild(stackHeader);
            content.appendChild(stackList);

            // 网络请求
            const reqHeader = document.createElement('div');
            reqHeader.style.cssText = `
                font-size: 13px;
                font-weight: 600;
                color: #666;
                margin-top: 15px;
                padding-bottom: 5px;
            `;
            reqHeader.textContent = '网络请求';

            const requestList = document.createElement('div');
            requestList.id = 'wb-debug-requests';
            requestList.style.cssText = `
                max-height: 150px;
                overflow-y: auto;
                font-size: 11px;
                line-height: 1.6;
            `;
            requestList.innerHTML = '<div style="color: #999; padding: 10px; text-align: center;">暂无网络请求</div>';
            content.appendChild(reqHeader);
            content.appendChild(requestList);

            // 错误信息面板（默认隐藏）
            const errorPanel = document.createElement('div');
            errorPanel.id = 'wb-debug-error-panel';
            errorPanel.style.cssText = `
                display: none;
                background: rgba(220, 53, 69, 0.95);
                border-radius: 8px;
                padding: 15px;
                margin-top: 10px;
                box-shadow: 0 4px 12px rgba(0, 0, 0, 0.2);
            `;
            errorPanel.innerHTML = `
                <div style="font-size: 16px; font-weight: 600; color: #c53030; margin-bottom: 10px;">⚠️ 页面加载失败</div>
                <div style="font-size: 13px; color: #666; margin-bottom: 8px;">无法加载页面</div>
                <button onclick="window.location.reload()" style="
                    background: #4a5568;
                    color: white;
                    padding: 6px 12px;
                    border: none;
                    border-radius: 4px;
                    font-size: 13px;
                    margin-right: 5px;
                ">重新加载</button>
            `;

            content.appendChild(errorPanel);

            panel.appendChild(content);
        },

        // 切换面板
        togglePanel: function() {
            const panel = document.getElementById('wb-debug-panel');
            if (panel) {
                const isVisible = panel.style.display !== 'none';
                panel.style.display = isVisible ? 'none' : 'block';
                console.log('%c[WebBridge Debug] 面板: ' + (isVisible ? '隐藏' : '显示'), 'color: #2196F3');
            }
        },

        // 开始错误检测
        startErrorCheck: function() {
            // 每 500ms 检查一次
            setInterval(() => {
                if (document.readyState === 'complete') {
                    // 检查标题是否为空或默认
                    const title = document.title || '';
                    const isBlankOrAbout = title === '' || title === 'about:blank';

                    if (isBlankOrAbout) {
                        // 页面加载失败，显示错误面板
                        this.showErrorMessage();
                        this.checkErrorState();
                    }
                }
            }, CONFIG.checkInterval);
        },

        // 导出到全局
        togglePanel: togglePanel
    };

    // 启动
    window.addEventListener('load', () => {
        state.loadStartTime = Date.now();
        console.log('%c[WebBridge Debug] 页面开始加载', 'color: #4CAF50');
        state.updateUI();
    });

    // 初始化
    if (document.readyState === 'complete') {
        Debug.init();
    } else {
        document.addEventListener('DOMContentLoaded', () => {
            Debug.init();
        }, false);
    }

    // 导出到全局
    window.WebBridgeDebug = Debug;
})();
