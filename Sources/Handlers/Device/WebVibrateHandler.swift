//
//  WebVibrateHandler.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-13.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import AudioToolbox
import UIKit
import WebKit

// Framework imports

/// 震动处理器（简单震动）
public class WebVibrateHandler: BaseWebNativeHandler {

    /// 处理震动请求
    /// - Parameters:
    ///   - body: 包含 duration (震动时长，毫秒)
    ///   - completion: 结果回调
    public override func handle(body: [String: Any], completion: @escaping (Any) -> Void) {
        let duration = body["duration"] as? Int ?? 1000

        // 震动指定的毫秒数
        runOnMainThread {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            self.resolve(["duration": duration], completion: completion)
        }

        // 如果需要长时间震动，可以使用 Timer 重复触发
        if duration > 1000 {
            let repeats = duration / 1000
            for i in 1..<repeats {
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(i * 1000)) { [weak self] in
                    self?.runOnMainThread {
                        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                    }
                }
            }
        }
    }
}
