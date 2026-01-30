//
//  WebHapticHandler.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-13.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import UIKit
import WebKit

// Framework imports

/// 震动反馈处理器
/// 提供多种触感反馈样式（轻微、中等、沉重、成功、警告、错误等）
public class WebHapticHandler: BaseWebNativeHandler {

    /**
     * 处理震动反馈请求
     * - Parameters:
     *   - body: 包含 style 参数的字典
     *   - completion: 结果回调
     */
    public override func handle(body: [String: Any], completion: @escaping (Any) -> Void) {
        let style = body["style"] as? String ?? "medium"

        runOnMainThread {
            self.generateHaptic(style: style)
            self.resolve(["style": style], completion: completion)
        }
    }

    /**
     * 根据样式触发对应的系统震动反馈
     * - Parameter style: 反馈样式字符串
     */
    private func generateHaptic(style: String) {
        let generator: UIImpactFeedbackGenerator?

        switch style {
        case "light":
            generator = UIImpactFeedbackGenerator(style: .light)
        case "medium":
            generator = UIImpactFeedbackGenerator(style: .medium)
        case "heavy":
            generator = UIImpactFeedbackGenerator(style: .heavy)
        case "success":
            let notificationGenerator = UINotificationFeedbackGenerator()
            notificationGenerator.notificationOccurred(.success)
            return
        case "warning":
            let notificationGenerator = UINotificationFeedbackGenerator()
            notificationGenerator.notificationOccurred(.warning)
            return
        case "error":
            let notificationGenerator = UINotificationFeedbackGenerator()
            notificationGenerator.notificationOccurred(.error)
            return
        case "selection":
            let selectionGenerator = UISelectionFeedbackGenerator()
            selectionGenerator.selectionChanged()
            return
        default:
            generator = UIImpactFeedbackGenerator(style: .medium)
        }

        generator?.impactOccurred()
    }
}
