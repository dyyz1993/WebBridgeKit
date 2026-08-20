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

                // 调试日志
                console.log('=== BarkBridge.callNative ===');
                console.log('Action:', action, 'Type:', typeof action, 'IsEmpty:', action === '');
                console.log('Params:', params);

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

                console.log('Sending message to native:', JSON.stringify(message));

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

        /** Return from the current native PWA screen. */
        goBack: function() {
            return this.callNative('goBack', { steps: 1 });
        },

        /** Close the current native PWA screen and return to the host. */
        closePage: function() {
            return this.callNative('closePage', { animated: true, reason: 'javascript' });
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

    // Keep the public PWA API consistent with the framework bundle.
    window.WebBridgeKit = window.WebBridgeKit || {
        callNative: function(action, params) {
            return BarkBridge.callNative(action, params);
        },
        navigation: {
            back: function() { return BarkBridge.goBack(); },
            close: function() { return BarkBridge.closePage(); }
        },
        isAvailable: function() { return BarkBridge.isAvailable(); }
    };

    // 打印初始化日志
    console.log('[BarkBridge] Initialized successfully');
})();
