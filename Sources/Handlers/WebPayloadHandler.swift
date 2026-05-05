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
        let response = WebBridgeResponse.success(data: [
            "message": "Please access parameters via 'window.SuperCachePayload' for synchronous access.",
            "hint": "SuperCachePayload is injected at document start."
        ])

        completion(response.toDictionary())
    }
}
