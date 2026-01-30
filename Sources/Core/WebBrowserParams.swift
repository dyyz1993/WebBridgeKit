//
//  WebBrowserParams.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-14.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import UIKit

// Framework imports

/// 浏览器打开参数配置
public struct WebBrowserParams {

    // MARK: - Display Mode

    public enum DisplayMode: String {
        case normal       // 标准全屏模式
        case immersive    // 沉浸式模式（隐藏状态栏和导航栏）
        case modal        // 弹窗模式

        public static func from(string: String) -> DisplayMode {
            switch string.lowercased() {
            case "immersive": return .immersive
            case "modal": return .modal
            default: return .normal
            }
        }
    }

    // MARK: - Modal Size

    public enum ModalSize {
        case fullscreen
        case half
        case percent(width: String, height: String)

        public static func from(string: String) -> ModalSize {
            switch string.lowercased() {
            case "fullscreen": return .fullscreen
            case "half": return .half
            default: return .percent(width: "80%", height: "80%")
            }
        }
    }

    // MARK: - Close Reason

    public enum CloseReason: String {
        case userAction
        case javascript
        case systemGesture
        case backgroundTap
        case timeout
        case error

        public static func from(string: String) -> CloseReason {
            switch string.lowercased() {
            case "javascript": return .javascript
            case "system_gesture": return .systemGesture
            case "background_tap": return .backgroundTap
            case "timeout": return .timeout
            case "error": return .error
            default: return .userAction
            }
        }
    }

    // MARK: - Properties

    public let displayMode: DisplayMode
    public let modalSize: ModalSize
    public let showMask: Bool
    public let clickMaskCloses: Bool
    public let showCloseButton: Bool
    public let hideNavigationBar: Bool
    public let hideStatusBar: Bool
    public let hideTabBar: Bool           // 🔥 隐藏底部 Tab Bar
    public let disableSwipeBack: Bool     // 🔥 禁用侧滑返回手势
    public let orientation: UIInterfaceOrientationMask
    public let allowJavaScriptClose: Bool
    public let customTitle: String?

    // MARK: - Initialization

    public init(
        displayMode: DisplayMode = .normal,
        modalSize: ModalSize = .percent(width: "80%", height: "80%"),
        showMask: Bool = true,
        clickMaskCloses: Bool = true,
        showCloseButton: Bool = true,
        hideNavigationBar: Bool = false,
        hideStatusBar: Bool = false,
        hideTabBar: Bool = false,         // 🔥 默认显示 Tab Bar
        disableSwipeBack: Bool = false,   // 🔥 默认允许侧滑返回
        orientation: UIInterfaceOrientationMask = .all,
        allowJavaScriptClose: Bool = true,
        customTitle: String? = nil
    ) {
        self.displayMode = displayMode
        self.modalSize = modalSize
        self.showMask = showMask
        self.clickMaskCloses = clickMaskCloses
        self.showCloseButton = showCloseButton
        self.hideNavigationBar = hideNavigationBar
        self.hideStatusBar = hideStatusBar
        self.hideTabBar = hideTabBar
        self.disableSwipeBack = disableSwipeBack
        self.orientation = orientation
        self.allowJavaScriptClose = allowJavaScriptClose
        self.customTitle = customTitle
    }

    // MARK: - Factory Methods

    /// 从 URL 解析参数
    public static func from(url: URL) -> WebBrowserParams {
        // 获取默认值
        var displayMode: DisplayMode = .normal
        var modalSize: ModalSize = .percent(width: "80%", height: "80%")
        var showMask: Bool = true
        var clickMaskCloses: Bool = true
        var showCloseButton: Bool = true
        var hideNavigationBar: Bool = false
        var hideStatusBar: Bool = false
        var hideTabBar: Bool = false
        var disableSwipeBack: Bool = false
        var orientation: UIInterfaceOrientationMask = .all
        var allowJavaScriptClose: Bool = true
        var customTitle: String? = nil

        // 辅助函数获取当前宽高
        func getCurrentWidth() -> String {
            if case .percent(let width, _) = modalSize {
                return width
            }
            return "80%"
        }

        func getCurrentHeight() -> String {
            if case .percent(_, let height) = modalSize {
                return height
            }
            return "80%"
        }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return WebBrowserParams(
                displayMode: displayMode,
                modalSize: modalSize,
                showMask: showMask,
                clickMaskCloses: clickMaskCloses,
                showCloseButton: showCloseButton,
                hideNavigationBar: hideNavigationBar,
                hideStatusBar: hideStatusBar,
                hideTabBar: hideTabBar,
                disableSwipeBack: disableSwipeBack,
                orientation: orientation,
                allowJavaScriptClose: allowJavaScriptClose,
                customTitle: customTitle
            )
        }

        for item in queryItems {
            switch item.name.lowercased() {
            case "mode":
                if let value = item.value {
                    displayMode = DisplayMode.from(string: value)
                }
            case "modal":
                if let value = item.value {
                    modalSize = ModalSize.from(string: value)
                }
            case "width":
                if let value = item.value {
                    modalSize = .percent(width: value, height: getCurrentHeight())
                }
            case "height":
                if let value = item.value {
                    modalSize = .percent(width: getCurrentWidth(), height: value)
                }
            case "mask":
                showMask = (item.value == "true" || item.value == "1")
            case "clickmaskclose":
                clickMaskCloses = (item.value == "true" || item.value == "1")
            case "closebutton":
                showCloseButton = (item.value == "true" || item.value == "1")
            case "hidenavbar":
                hideNavigationBar = (item.value == "true" || item.value == "1")
            case "hidestatusbar":
                hideStatusBar = (item.value == "true" || item.value == "1")
            case "hidetabbar":
                hideTabBar = (item.value == "true" || item.value == "1")
            case "disableswipeback":
                disableSwipeBack = (item.value == "true" || item.value == "1")
            case "orientation":
                if let value = item.value {
                    orientation = parseOrientation(value)
                }
            case "allowclose":
                allowJavaScriptClose = (item.value == "true" || item.value == "1")
            case "title":
                customTitle = item.value
            default:
                break
            }
        }

        // 🔥 沉浸式模式自动隐藏 TabBar
        if displayMode == .immersive {
            hideTabBar = true
        }

        return WebBrowserParams(
            displayMode: displayMode,
            modalSize: modalSize,
            showMask: showMask,
            clickMaskCloses: clickMaskCloses,
            showCloseButton: showCloseButton,
            hideNavigationBar: hideNavigationBar,
            hideStatusBar: hideStatusBar,
            hideTabBar: hideTabBar,
            disableSwipeBack: disableSwipeBack,
            orientation: orientation,
            allowJavaScriptClose: allowJavaScriptClose,
            customTitle: customTitle
        )
    }

    /// 默认配置
    public static let `default` = WebBrowserParams()

    // MARK: - Helper Methods

    private func getWidth() -> String {
        if case .percent(let width, _) = modalSize {
            return width
        }
        return "80%"
    }

    private func getHeight() -> String {
        if case .percent(_, let height) = modalSize {
            return height
        }
        return "80%"
    }

    private static func parseOrientation(_ value: String) -> UIInterfaceOrientationMask {
        switch value.lowercased() {
        case "portrait": return .portrait
        case "landscape": return .landscape
        case "landscapeleft": return .landscapeLeft
        case "landscaperight": return .landscapeRight
        case "auto": return .all
        default: return .all
        }
    }
}

// MARK: - Modal Config for ViewController

extension WebBrowserParams {
    public struct ModalConfig {
        public var widthPercent: CGFloat
        public var heightPercent: CGFloat
        public var showMask: Bool
        public var clickMaskCloses: Bool
        public let cornerRadius: CGFloat
        public let shadowOpacity: Float

        public init(
            widthPercent: CGFloat = 0.8,
            heightPercent: CGFloat = 0.8,
            showMask: Bool = true,
            clickMaskCloses: Bool = true,
            cornerRadius: CGFloat = 12,
            shadowOpacity: Float = 0.3
        ) {
            self.widthPercent = widthPercent
            self.heightPercent = heightPercent
            self.showMask = showMask
            self.clickMaskCloses = clickMaskCloses
            self.cornerRadius = cornerRadius
            self.shadowOpacity = shadowOpacity
        }

        public static let `default` = ModalConfig()
    }

    public func toModalConfig() -> ModalConfig {
        switch modalSize {
        case .fullscreen:
            return ModalConfig(widthPercent: 1, heightPercent: 1, showMask: showMask, clickMaskCloses: clickMaskCloses)
        case .half:
            return ModalConfig(widthPercent: 1, heightPercent: 0.5, showMask: showMask, clickMaskCloses: clickMaskCloses)
        case .percent(let widthStr, let heightStr):
            let w = Float(widthStr.replacingOccurrences(of: "%", with: "")) ?? 80
            let h = Float(heightStr.replacingOccurrences(of: "%", with: "")) ?? 80
            return ModalConfig(widthPercent: CGFloat(w) / 100, heightPercent: CGFloat(h) / 100, showMask: showMask, clickMaskCloses: clickMaskCloses)
        }
    }
}
