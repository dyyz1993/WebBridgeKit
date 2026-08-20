//
//  WebBridge.js
//  Bark
//
//  Created by Claude on 2025-01-13.
//  Copyright © 2025年 Fin. All rights reserved.
//
//  JavaScript Bridge for calling native iOS capabilities

(function() {
    'use strict';

    function nativeModuleUnavailable(action) {
        const message = '\u5f53\u524d\u5bb9\u5668\u672a\u63d0\u4f9b ' + action + ' \u539f\u751f\u6a21\u5757\uff0c\u8bf7\u5728 WebBridgeKit \u4e2d\u6253\u5f00\u3002';
        return {
            success: false,
            available: false,
            code: 'NATIVE_MODULE_UNAVAILABLE',
            module: action,
            error: message,
            message: message
        };
    }

    // 确保 BarkBridge 只初始化一次
    if (window.BarkBridge) {
        return;
    }

    window.BarkBridge = {
        // 回调存储
        callbacks: {},

        // 当前消息 ID
        messageId: 0,

        /**
         * 调用原生能力 (Promise 版本)
         * @param {string} action - 动作名称
         * @param {object} params - 参数
         * @returns {Promise}
         */
        callNative: function(action, params) {
            return new Promise((resolve, reject) => {
                if (!this.isAvailable()) {
                    resolve(nativeModuleUnavailable(action));
                    return;
                }

                const messageId = 'msg_' + Date.now() + '_' + (this.messageId++);

                // 保存回调
                this.callbacks[messageId] = function(result) {
                    if (result.success !== false) {
                        resolve(result);
                    } else {
                        reject(new Error(result.error || 'Operation failed'));
                    }
                };

                // 准备消息体
                const message = {
                    action: action,
                    params: params || {},
                    messageId: messageId,
                    callbackId: messageId
                };

                // 发送消息到原生
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.BarkBridge) {
                    window.webkit.messageHandlers.BarkBridge.postMessage(message);
                } else {
                    delete this.callbacks[messageId];
                    resolve(nativeModuleUnavailable(action));
                }
            });
        },

        /**
         * 调用原生能力 (回调版本 - 兼容旧代码)
         * @param {string} action - 动作名称
         * @param {object} params - 参数
         * @param {function} callback - 回调函数
         */
        callNativeWithCallback: function(action, params, callback) {
            const messageId = 'msg_' + Date.now() + '_' + (this.messageId++);

            // 保存回调
            if (callback) {
                this.callbacks[messageId] = callback;
            }

            // 准备消息体
            const message = {
                action: action,
                params: params || {},
                messageId: messageId,
                callbackId: messageId
            };

            // 发送消息到原生
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.BarkBridge) {
                window.webkit.messageHandlers.BarkBridge.postMessage(message);
            } else {
                if (callback) {
                    callback(nativeModuleUnavailable(action));
                    delete this.callbacks[messageId];
                }
            }
        },

        /**
         * 接收原生返回的结果
         * @param {object} result - 结果对象
         */
        receiveResult: function(result) {
            const callbackId = result.callbackId || result.messageId;
            if (callbackId && this.callbacks[callbackId]) {
                const callback = this.callbacks[callbackId];
                callback(result);
                delete this.callbacks[callbackId];
            }
        },

        /**
         * 分享功能
         * @param {string} text - 分享文本
         * @param {string} url - 分享链接
         * @param {function} callback - 回调函数
         */
        share: function(text, url, callback) {
            this.callNative('share', { text: text, url: url }, callback);
        },

        /**
         * 获取定位
         * @param {function} callback - 回调函数
         */
        getLocation: function(callback) {
            this.callNative('getLocation', {}, callback);
        },

        /**
         * 请求权限
         * @param {string} type - 权限类型 (location/notification/camera/microphone)
         * @param {function} callback - 回调函数
         */
        requestPermission: function(type, callback) {
            this.callNative('requestPermission', { type: type }, callback);
        },

        /**
         * 检查权限状态
         * @param {string} type - 权限类型
         * @param {function} callback - 回调函数
         */
        checkPermission: function(type, callback) {
            this.requestPermission(type, function(result) {
                callback(result);
            });
        },

        /**
         * Promise 版本的 API
         */
        shareAsync: function(text, url) {
            return new Promise((resolve, reject) => {
                this.share(text, url, function(result) {
                    if (result.success) {
                        resolve(result);
                    } else {
                        reject(new Error(result.error || 'Share failed'));
                    }
                });
            });
        },

        getLocationAsync: function() {
            return new Promise((resolve, reject) => {
                this.getLocation(function(result) {
                    if (result.success) {
                        resolve(result);
                    } else {
                        reject(new Error(result.error || 'Get location failed'));
                    }
                });
            });
        },

        requestPermissionAsync: function(type) {
            return new Promise((resolve, reject) => {
                this.requestPermission(type, function(result) {
                    if (result.success) {
                        resolve(result);
                    } else {
                        reject(new Error(result.error || 'Request permission failed'));
                    }
                });
            });
        },

        /**
         * 工具方法
         */

        // 检测 BarkBridge 是否可用
        isAvailable: function() {
            return !!(window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.BarkBridge);
        },

        // 调试日志
        log: function(message) {
            if (console && console.log) {
                console.log('[BarkBridge]', message);
            }
        }
    };

    // 监听原生消息（用于双向通信）
    document.addEventListener('BarkBridgeMessage', function(event) {
        const data = event.detail;
        if (data.type && BarkBridge['on' + data.type]) {
            BarkBridge['on' + data.type](data);
        }
    });

    // 打印初始化日志
    console.log('[BarkBridge] Initialized successfully');

    // ===== WebBridgeKit API =====
    // 提供更现代化的 Promise-based API
    window.WebBridgeKit = {
        /**
         * Call a native module. In a normal browser this resolves to a
         * structured unavailable result instead of throwing a TypeError.
         */
        callNative: function(action, params) {
            return BarkBridge.callNative(action, params);
        },
        /**
         * 权限管理
         * @param {object} params - { type: 'camera' | 'microphone' | 'location' }
         * @returns {Promise<{granted: boolean, status: number}>}
         */
        permission: function(params) {
            return BarkBridge.callNative('requestPermission', params);
        },

        /**
         * 相机功能
         * @param {object} params - { type: 'photo' | 'video' }
         * @returns {Promise<{type: string, data: string, width: number, height: number, size: number, cancelled?: boolean}>}
         */
        camera: function(params) {
            return BarkBridge.callNative('camera', params);
        },

        /**
         * 定位功能
         * @param {object} params - {}
         * @returns {Promise<{latitude: number, longitude: number, accuracy: number}>}
         */
        location: function(params) {
            return BarkBridge.callNative('getLocation', params);
        },

        /**
         * 分享功能
         * @param {object} params - { text: string, url?: string }
         * @returns {Promise<{success: boolean}>}
         */
        share: function(params) {
            return BarkBridge.callNative('share', params);
        },

        /**
         * 扫码功能
         * @param {object} params - {}
         * @returns {Promise<{code: string, type: string}>}
         */
        scan: function(params) {
            return BarkBridge.callNative('scan', params);
        },

        /**
         * 触觉反馈
         * @param {object} params - { style: 'light' | 'medium' | 'heavy' | 'success' | 'warning' | 'error' }
         * @returns {Promise<{success: boolean}>}
         */
        haptic: function(params) {
            return BarkBridge.callNative('haptic', params);
        },

        /**
         * 网络请求
         * @param {object} params - { url: string, method?: string, headers?: object, body?: string }
         * @returns {Promise<{data: string, statusCode: number, headers: object}>}
         */
        request: function(params) {
            return BarkBridge.callNative('request', params);
        },

        /**
         * 导航控制
         * @param {object} params - { action: 'push' | 'pop' | 'popToRoot', url?: string }
         * @returns {Promise<{success: boolean}>}
         */
        navigation: function(params) {
            return BarkBridge.callNative('navigation', params);
        },

        /** Return from the current native PWA screen. */
        back: function() {
            return BarkBridge.callNative('goBack', { steps: 1 });
        },

        /** Close the current native PWA screen and return to the host. */
        close: function() {
            return BarkBridge.callNative('closePage', { animated: true, reason: 'javascript' });
        },

        /**
         * 检查 WebBridgeKit 是否可用
         * @returns {boolean}
         */
        isAvailable: function() {
            return BarkBridge.isAvailable();
        }
    };

    console.log('[WebBridgeKit] Initialized successfully');
})();
