//
//  WebSpeechSynthesisHandler.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-14.
//

import UIKit
import WebKit
import AVFoundation

// Framework imports

/// 语音合成 (TTS) Handler
/// 支持：文本转语音播报
public class WebSpeechSynthesisHandler: BaseWebNativeHandler {

    // MARK: - Properties

    private let synthesizer = AVSpeechSynthesizer()

    // MARK: - Handle

    /**
     * 处理 JS 调用
     * @param body 调用参数
     * @param completion 处理完成后的回调
     */
    public override func handle(body: [String: Any], completion: @escaping (Any) -> Void) {
        let params = body["params"] as? [String: Any] ?? body
        let action = params["action"] as? String ?? ""

        WebBridgeLogger.shared.log(.info, "[WebSpeechSynthesisHandler] Handling action: \(action)")

        switch action {
        case "speak":
            let text = params["text"] as? String ?? ""
            let lang = params["lang"] as? String ?? "zh-CN"
            let rate = params["rate"] as? Float ?? 0.5
            speak(text: text, lang: lang, rate: rate, completion: completion)

        case "stop":
            stop(completion: completion)

        default:
            self.reject(error: "Unsupported action: \(action)", code: 404, completion: completion)
        }
    }

    // MARK: - Actions

    /**
     * 开始语音播报
     * @param text 文本内容
     * @param lang 语言代码
     * @param rate 语速 (0.0 - 1.0)
     * @param completion 返回结果
     */
    private func speak(text: String, lang: String, rate: Float, completion: @escaping (Any) -> Void) {
        runOnMainThread { [weak self] in
            guard let self = self else { return }

            if self.synthesizer.isSpeaking {
                self.synthesizer.stopSpeaking(at: .immediate)
            }

            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: lang)
            utterance.rate = rate

            self.synthesizer.speak(utterance)
            WebBridgeLogger.shared.log(.info, "[WebSpeechSynthesisHandler] Speaking: \(text)")
            self.resolve(["status": "speaking"], completion: completion)
        }
    }

    /**
     * 停止语音播报
     * @param completion 返回结果
     */
    private func stop(completion: @escaping (Any) -> Void) {
        runOnMainThread { [weak self] in
            self?.synthesizer.stopSpeaking(at: .immediate)
            self?.resolve(["status": "stopped"], completion: completion)
        }
    }
}
