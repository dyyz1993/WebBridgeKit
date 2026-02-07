//
//  WebPayloadHandler.swift
//  WebBridgeKit
//
//  Created on 2026-02-07.
//

import Foundation
import WebKit

/// 获取透传参数 (Payload) 的 Handler
public class WebPayloadHandler: BaseWebNativeHandler {
    
    // MARK: - Handle
    
    public override func handle(body: [String: Any], completion: @escaping (Any) -> Void) {
        // 从当前绑定的 WebViewController 中获取 params
        // 这里可以通过通知或者单例获取当前正在显示的参数
        // 但由于我们已经通过 window.SuperCachePayload 注入了，这个 Handler 主要作为补充
        
        // 尝试从 WebView 关联的对象中获取（如果有的话）
        // 这里我们简单返回一个成功响应，并提示用户优先使用全局变量
        
        let response = WebBridgeResponse.success(data: [
            "message": "Please access parameters via 'window.SuperCachePayload' for synchronous access.",
            "hint": "SuperCachePayload is injected at document start."
        ])
        
        completion(response)
    }
}
