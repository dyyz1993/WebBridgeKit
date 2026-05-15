//
//  TokenManager.swift
//  SuperApp
//
//  Created on 2026-02-07.
//

import Foundation
import RxSwift
import RxCocoa
import WebBridgeKit

@MainActor
class TokenManager {

    static let shared = TokenManager()

    private let disposeBag = DisposeBag()

    private init() {}

    /// 解析口令内容
    /// 格式示例: #SuperCache:TOKEN_VALUE#
    func parseTokenFromClipboard() {
        guard let content = UIPasteboard.general.string else { return }
        processTokenString(content)
    }

    /// 处理潜在的消息/口令字符串
    func processTokenString(_ content: String) {
        // 匹配格式: #SuperCache:([A-Za-z0-9]+)#
        let pattern = "#SuperCache:([A-Za-z0-9]+)#"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)) else {
            return
        }

        let tokenRange = match.range(at: 1)
        guard let range = Range(tokenRange, in: content) else { return }
        let token = String(content[range])

        print("🔍 [TokenManager] Found token: \(token)")
        resolveToken(token)
    }

    /// 向服务器解析口令
    private func resolveToken(_ token: String) {
        // 模拟服务器请求逻辑
        // 在真实场景中，这里会调用 API 服务端（如配置的开源服务端地址）

        Task { @MainActor in
            // 模拟网络延迟
            try? await Task.sleep(nanoseconds: 1_000_000_000)

            // 模拟解析结果
            // 假设解析出了一个 AppID 和对应的 URL
            let mockAppID = "com.example.app"
            let mockURL = "https://wbk.shanbox.19930810.xyz:8443/test_resources/bridge-hub.html"

            print("✅ [TokenManager] Token resolved: \(mockAppID) -> \(mockURL)")

            self.handleResolvedResult(appId: mockAppID, urlString: mockURL)
        }
    }

    private func handleResolvedResult(appId: String, urlString: String) {
        guard URL(string: urlString) != nil else { return }

        Task {
            let payload = MessagePayload(
                title: "口令解析成功",
                body: "已自动为您匹配应用: \(appId)",
                channel: "token",
                targetURL: urlString,
                targetAppId: appId
            )
            try? await MessageEngine.shared.receive(payload)
        }

        UIPasteboard.general.string = ""
    }
}
