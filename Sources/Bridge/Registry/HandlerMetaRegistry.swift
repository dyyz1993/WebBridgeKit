//
//  HandlerMetaRegistry.swift
//  WebBridgeKit
//

import Foundation

/// 所有 Handler 的元数据集中注册
/// 在 WebBridgeKit.initialize() 时调用 registerAll() 完成注册
public class HandlerMetaRegistry {

    public static let registerAll: () -> Void = {
        let registry = HandlerRegistry.shared

        // MARK: - Hardware

        registry.register(HandlerMeta(
            action: "camera",
            category: .hardware,
            displayName: "相机",
            description: "调用设备摄像头拍照或录像",
            requiredPermissions: ["camera"],
            parameters: [
                ParamDef(name: "mode", type: .string, required: false, defaultValue: "photo",
                         description: "拍照模式", options: ["photo", "video"]),
                ParamDef(name: "quality", type: .string, required: false, defaultValue: "high",
                         description: "画质", options: ["high", "medium", "low"])
            ],
            returns: [
                ReturnDef(name: "data", type: .string, description: "Base64 编码的图片/视频"),
                ReturnDef(name: "mimeType", type: .string, description: "媒体类型")
            ],
            requiresHardware: true
        ))

        registry.register(HandlerMeta(
            action: "bluetooth",
            category: .hardware,
            displayName: "蓝牙",
            description: "扫描 BLE 蓝牙设备",
            requiredPermissions: ["bluetooth"],
            returns: [
                ReturnDef(name: "devices", type: .array, description: "扫描到的设备列表")
            ],
            requiresHardware: true
        ))

        registry.register(HandlerMeta(
            action: "getLocation",
            category: .hardware,
            displayName: "定位",
            description: "获取当前 GPS 位置",
            requiredPermissions: ["location"],
            parameters: [
                ParamDef(name: "accuracy", type: .string, required: false, defaultValue: "high",
                         description: "定位精度", options: ["best", "high", "medium", "low"])
            ],
            returns: [
                ReturnDef(name: "latitude", type: .double, description: "纬度"),
                ReturnDef(name: "longitude", type: .double, description: "经度"),
                ReturnDef(name: "accuracy", type: .double, description: "精度（米）")
            ],
            requiresHardware: true
        ))

        registry.register(HandlerMeta(
            action: "scan",
            category: .hardware,
            displayName: "扫码",
            description: "扫描 QR 码/条形码",
            requiredPermissions: ["camera"],
            returns: [
                ReturnDef(name: "content", type: .string, description: "扫描结果"),
                ReturnDef(name: "format", type: .string, description: "码格式")
            ],
            requiresHardware: true
        ))

        // MARK: - Feedback

        registry.register(HandlerMeta(
            action: "haptic",
            category: .feedback,
            displayName: "触感反馈",
            description: "触发设备触感反馈",
            parameters: [
                ParamDef(name: "type", type: .string, required: false, defaultValue: "medium",
                         description: "反馈类型", options: ["light", "medium", "heavy", "success", "warning", "error"])
            ]
        ))

        registry.register(HandlerMeta(
            action: "vibrate",
            category: .feedback,
            displayName: "振动",
            description: "触发设备振动",
            parameters: [
                ParamDef(name: "duration", type: .double, required: false, defaultValue: "0.3",
                         description: "振动时长（秒）")
            ]
        ))

        // MARK: - Media

        registry.register(HandlerMeta(
            action: "photo",
            category: .media,
            displayName: "相册",
            description: "从相册选取照片",
            requiredPermissions: ["photoLibrary"],
            parameters: [
                ParamDef(name: "maxCount", type: .int, required: false, defaultValue: "1",
                         description: "最大选取数量")
            ],
            returns: [
                ReturnDef(name: "images", type: .array, description: "Base64 图片数组")
            ],
            minimumiOSVersion: "14.0"
        ))

        registry.register(HandlerMeta(
            action: "media",
            category: .media,
            displayName: "媒体操作",
            description: "保存图片/文件/上传",
            parameters: [
                ParamDef(name: "action", type: .string, required: true,
                         description: "操作类型", options: ["saveImage", "saveFile", "upload"])
            ]
        ))

        registry.register(HandlerMeta(
            action: "share",
            category: .media,
            displayName: "分享",
            description: "弹出系统分享面板",
            parameters: [
                ParamDef(name: "text", type: .string, required: false, description: "分享文本"),
                ParamDef(name: "url", type: .string, required: false, description: "分享 URL"),
                ParamDef(name: "image", type: .string, required: false, description: "Base64 图片")
            ]
        ))

        // MARK: - Sensor

        registry.register(HandlerMeta(
            action: "audioLevel",
            category: .sensor,
            displayName: "音频电平",
            description: "实时麦克风音量监听",
            requiredPermissions: ["microphone"],
            requiresHardware: true
        ))

        registry.register(HandlerMeta(
            action: "sensors",
            category: .sensor,
            displayName: "传感器",
            description: "加速度计/陀螺仪/设备运动数据",
            parameters: [
                ParamDef(name: "type", type: .string, required: false, defaultValue: "accelerometer",
                         description: "传感器类型", options: ["accelerometer", "gyroscope", "deviceMotion"]),
                ParamDef(name: "interval", type: .double, required: false, defaultValue: "0.1",
                         description: "采样间隔（秒）")
            ],
            requiresHardware: true
        ))

        // MARK: - Speech

        registry.register(HandlerMeta(
            action: "speech",
            category: .speech,
            displayName: "语音识别",
            description: "实时语音转文字",
            requiredPermissions: ["microphone"],
            requiresHardware: true
        ))

        registry.register(HandlerMeta(
            action: "tts",
            category: .speech,
            displayName: "语音合成",
            description: "文字转语音",
            parameters: [
                ParamDef(name: "action", type: .string, required: false, defaultValue: "speak",
                         description: "操作", options: ["speak", "stop"]),
                ParamDef(name: "text", type: .string, required: false, description: "要朗读的文本"),
                ParamDef(name: "lang", type: .string, required: false, defaultValue: "zh-CN",
                         description: "语言代码"),
                ParamDef(name: "rate", type: .double, required: false, defaultValue: "0.5",
                         description: "语速 0.0-1.0")
            ]
        ))

        // MARK: - Clipboard

        registry.register(HandlerMeta(
            action: "clipboard",
            category: .clipboard,
            displayName: "剪贴板",
            description: "读写系统剪贴板",
            parameters: [
                ParamDef(name: "action", type: .string, required: true,
                         description: "操作类型", options: ["read", "write"]),
                ParamDef(name: "text", type: .string, required: false, description: "要写入的文本（write 时必填）")
            ],
            returns: [
                ReturnDef(name: "text", type: .string, description: "剪贴板内容（read 时返回）")
            ]
        ))

        // MARK: - System

        registry.register(HandlerMeta(
            action: "getSystemInfo",
            category: .system,
            displayName: "系统信息",
            description: "获取设备信息、电量、版本等",
            returns: [
                ReturnDef(name: "deviceModel", type: .string, description: "设备型号"),
                ReturnDef(name: "osVersion", type: .string, description: "系统版本"),
                ReturnDef(name: "batteryLevel", type: .double, description: "电量 0.0-1.0"),
                ReturnDef(name: "screenSize", type: .string, description: "屏幕尺寸")
            ]
        ))

        registry.register(HandlerMeta(
            action: "getNetworkInfo",
            category: .system,
            displayName: "网络信息",
            description: "获取网络连接状态和类型",
            returns: [
                ReturnDef(name: "isConnected", type: .bool, description: "是否联网"),
                ReturnDef(name: "type", type: .string, description: "网络类型 WiFi/Cellular/None")
            ]
        ))

        registry.register(HandlerMeta(
            action: "systemExtra",
            category: .system,
            displayName: "系统扩展",
            description: "Face ID/Touch ID、手电筒、Badge 等系统功能",
            parameters: [
                ParamDef(name: "action", type: .string, required: true,
                         description: "操作类型", options: ["biometricAuth", "flashlight", "setBadge"])
            ]
        ))

        registry.register(HandlerMeta(
            action: "openSettings",
            category: .system,
            displayName: "打开设置",
            description: "跳转到 iOS 系统设置"
        ))

        registry.register(HandlerMeta(
            action: "contacts",
            category: .system,
            displayName: "通讯录",
            description: "访问设备通讯录",
            requiredPermissions: ["contacts"],
            parameters: [
                ParamDef(name: "action", type: .string, required: true,
                         description: "操作类型", options: ["pick", "fetchAll"])
            ]
        ))

        registry.register(HandlerMeta(
            action: "layout",
            category: .system,
            displayName: "布局控制",
            description: "控制横竖屏、全屏等",
            parameters: [
                ParamDef(name: "orientation", type: .string, required: false,
                         options: ["portrait", "landscape"]),
                ParamDef(name: "fullscreen", type: .bool, required: false, description: "全屏模式"),
                ParamDef(name: "scrollEnabled", type: .bool, required: false, description: "滚动开关")
            ]
        ))

        registry.register(HandlerMeta(
            action: "screen",
            category: .system,
            displayName: "屏幕控制",
            description: "防偷窥黑屏、屏幕常亮等",
            parameters: [
                ParamDef(name: "action", type: .string, required: true,
                         options: ["stealthMode", "keepScreenOn", "brightness"])
            ]
        ))

        registry.register(HandlerMeta(
            action: "gesture",
            category: .system,
            displayName: "手势配置",
            description: "配置下拉刷新、滑动等手势",
            parameters: [
                ParamDef(name: "gesture", type: .string, required: true,
                         options: ["pullToRefresh", "swipe", "longPress", "doubleTap"]),
                ParamDef(name: "enabled", type: .bool, required: false, defaultValue: "true")
            ]
        ))

        registry.register(HandlerMeta(
            action: "mirroring",
            category: .system,
            displayName: "投屏检测",
            description: "检测屏幕镜像/投屏状态"
        ))

        // MARK: - Permission

        registry.register(HandlerMeta(
            action: "requestPermission",
            category: .permission,
            displayName: "请求权限",
            description: "请求系统权限",
            parameters: [
                ParamDef(name: "permission", type: .string, required: true,
                         description: "权限类型",
                         options: ["camera", "location", "microphone", "photoLibrary", "contacts", "notification"])
            ],
            returns: [
                ReturnDef(name: "granted", type: .bool, description: "是否授权")
            ]
        ))

        registry.register(HandlerMeta(
            action: "getPermissionStatus",
            category: .permission,
            displayName: "权限状态",
            description: "查询所有权限状态",
            returns: [
                ReturnDef(name: "permissions", type: .object, description: "权限状态字典")
            ]
        ))

        // MARK: - Navigation

        registry.register(HandlerMeta(
            action: "openPage",
            category: .navigation,
            displayName: "打开页面",
            description: "打开一个新的 WebView 页面",
            parameters: [
                ParamDef(name: "url", type: .string, required: true, description: "页面 URL"),
                ParamDef(name: "mode", type: .string, required: false, defaultValue: "normal",
                         description: "显示模式", options: ["normal", "immersive", "modal"]),
                ParamDef(name: "title", type: .string, required: false, description: "自定义标题")
            ]
        ))

        registry.register(HandlerMeta(
            action: "closePage",
            category: .navigation,
            displayName: "关闭页面",
            description: "关闭当前 WebView 页面"
        ))

        registry.register(HandlerMeta(
            action: "goBack",
            category: .navigation,
            displayName: "后退",
            description: "导航后退",
            parameters: [
                ParamDef(name: "steps", type: .int, required: false, defaultValue: "1",
                         description: "后退步数")
            ]
        ))

        registry.register(HandlerMeta(
            action: "getHistory",
            category: .navigation,
            displayName: "导航历史",
            description: "获取页面导航历史栈",
            returns: [
                ReturnDef(name: "history", type: .array, description: "URL 列表")
            ]
        ))

        registry.register(HandlerMeta(
            action: "getPayload",
            category: .navigation,
            displayName: "获取参数",
            description: "获取从原生传递到网页的参数",
            returns: [
                ReturnDef(name: "payload", type: .object, description: "传递的参数")
            ]
        ))

        registry.register(HandlerMeta(
            action: "setModal",
            category: .navigation,
            displayName: "调整弹窗",
            description: "动态调整弹窗大小",
            parameters: [
                ParamDef(name: "width", type: .double, required: false, description: "宽度比例 0.0-1.0"),
                ParamDef(name: "height", type: .double, required: false, description: "高度比例 0.0-1.0")
            ]
        ))

        // MARK: - File

        registry.register(HandlerMeta(
            action: "file",
            category: .file,
            displayName: "文件选择",
            description: "打开文件选择器",
            parameters: [
                ParamDef(name: "types", type: .array, required: false, description: "允许的文件类型"),
                ParamDef(name: "multiple", type: .bool, required: false, defaultValue: "false",
                         description: "是否允许多选")
            ]
        ))

        // MARK: - Cache & Debug

        registry.register(HandlerMeta(
            action: "page",
            category: .cache,
            displayName: "页面缓存",
            description: "预加载/缓存页面",
            parameters: [
                ParamDef(name: "action", type: .string, required: true,
                         options: ["preload", "cache", "removeCache"])
            ]
        ))

        registry.register(HandlerMeta(
            action: "cacheDebug",
            category: .debug,
            displayName: "缓存调试",
            description: "缓存调试 API",
            parameters: [
                ParamDef(name: "action", type: .string, required: true,
                         options: ["getInfo", "entries", "rules", "clear"])
            ]
        ))

        StructuredLogger.shared.info(
            "Registered \(registry.count) handlers",
            category: .bridge
        )

        return {}
    }()
}
