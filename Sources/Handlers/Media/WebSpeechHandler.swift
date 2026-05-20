//
//  WebSpeechHandler.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-13.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import AVFoundation
import Foundation
import Speech
import WebKit
import UIKit

// Framework imports

/// 语音识别处理器
/// 支持实时部分结果流式返回
public class WebSpeechHandler: BaseWebNativeHandler {

    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var timeoutTimer: DispatchWorkItem?
    private let recognitionTimeout: TimeInterval = 30  // 给用户30秒时间说话

    // 状态标志：防止重复调用
    private var isRecognizing = false
    private var isTapInstalled = false

    /// 处理语音识别请求
    /// - Parameters:
    ///   - body: 请求参数字典
    ///   - completion: 结果回调
    public override func handle(body: [String: Any], completion: @escaping (Any) -> Void) {
        // 从 params 中获取参数，兼容直接在 body 中传参的情况
        let params = body["params"] as? [String: Any] ?? body
        let action = params["action"] as? String ?? ""
        let language = params["language"] as? String ?? "zh-CN"

        // 如果没有指定子操作，返回权限状态
        if action.isEmpty {
            checkPermission(completion: completion)
            return
        }

        switch action {
        case "start":
            startSpeechRecognition(language: language, completion: completion)
        case "stop":
            stopRecognition(completion: completion)
        case "checkPermission":
            checkPermission(completion: completion)
        default:
            reject(error: "Unknown action: \(action)", completion: completion)
        }
    }

    private func checkPermission(completion: @escaping (Any) -> Void) {
        runOnMainThread {
            let status = SFSpeechRecognizer.authorizationStatus()
            let authorized = status == .authorized

            self.resolve([
                "authorized": authorized,
                "status": self.permissionStatusString(status)
            ], completion: completion)
        }
    }

    private func permissionStatusString(_ status: SFSpeechRecognizerAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "authorized"
        case .denied: return "denied"
        case .restricted: return "restricted"
        case .notDetermined: return "notDetermined"
        default: return "unknown"
        }
    }

    /// 发送实时部分结果到 JavaScript
    /// - Parameters:
    ///   - text: 识别的文本
    ///   - isFinal: 是否是最终结果
    ///   - confidence: 准确度（0-1，可选）
    private func sendPartialResult(_ text: String, isFinal: Bool, confidence: Float? = nil) {
        var data: [String: Any] = [
            "text": text,
            "isFinal": isFinal
        ]

        if let conf = confidence {
            data["confidence"] = conf
        }

        sendEventToJS(event: "onSpeechPartialResult", data: data)
    }

    private func escapeJSString(_ str: String) -> String {
        return str.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }

    private func startSpeechRecognition(language: String, completion: @escaping (Any) -> Void) {
        runOnMainThread { [weak self] in
            // 在入口处就检查：防止重复调用
            guard let self = self else { return }

            if self.isRecognizing {
                StructuredLogger.shared.warning("⚠️ [Speech] Recognition already in progress (at entry point), rejecting request", category: .handler)
                self.reject(error: "语音识别正在进行中，请先等待当前识别完成", code: 409, completion: completion)
                return
            }

            // 先检查是否支持
            guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: language)) else {
                self.reject(error: "不支持该语言: \(language)", completion: completion)
                return
            }

            self.recognizer = recognizer

            // 先检查当前权限状态
            let currentStatus = SFSpeechRecognizer.authorizationStatus()
            StructuredLogger.shared.debug("🎤 [Speech] Current speech recognition status: \(self.permissionStatusString(currentStatus))", category: .handler)

            if currentStatus == .authorized {
                // 已有权限，直接请求麦克风权限
                self.requestMicrophonePermission(completion: completion)
            } else if currentStatus == .notDetermined {
                // 未确定，请求权限
                StructuredLogger.shared.debug("🎤 [Speech] Requesting speech recognition authorization...", category: .handler)
                SFSpeechRecognizer.requestAuthorization { [weak self] status in
                    guard let self = self else { return }
                    StructuredLogger.shared.debug("🎤 [Speech] Authorization callback status: \(self.permissionStatusString(status))", category: .handler)

                    // 延迟检查状态，确保 iOS 已更新缓存
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                        guard let self = self else { return }
                        let refreshedStatus = SFSpeechRecognizer.authorizationStatus()
                        StructuredLogger.shared.debug("🎤 [Speech] Refreshed status after delay: \(self.permissionStatusString(refreshedStatus))", category: .handler)

                        guard refreshedStatus == .authorized else {
                            let permissionStatus = PermissionStatus(rawValue: self.permissionStatusString(refreshedStatus)) ?? .unknown
                            self.rejectPermissionDenied(type: .speech, status: permissionStatus, completion: completion)
                            return
                        }

                        self.requestMicrophonePermission(completion: completion)
                    }
                }
            } else {
                // 已拒绝或受限 - 使用框架统一的权限拒绝处理
                let permissionStatus = PermissionStatus(rawValue: self.permissionStatusString(currentStatus)) ?? .unknown
                self.rejectPermissionDenied(type: .speech, status: permissionStatus, completion: completion)
            }
        }
    }

    private func requestMicrophonePermission(completion: @escaping (Any) -> Void) {
        // 检查麦克风权限
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            guard granted else {
                // 麦克风权限被拒绝 - 使用框架统一的权限拒绝处理
                self?.rejectPermissionDenied(type: .microphone, status: .denied, completion: completion)
                return
            }

            StructuredLogger.shared.debug("🎤 [Speech] Microphone permission granted, starting recognition", category: .handler)
            self?.performRecognition(completion: completion)
        }
    }

    private func performRecognition(completion: @escaping (Any) -> Void) {
        // 停止之前的任务和定时器（安全清理）
        stopRecognitionInternal()
        timeoutTimer?.cancel()

        guard let recognizer = recognizer else {
            reject(error: "识别器未初始化", completion: completion)
            return
        }

        do {
            // 创建识别请求
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else {
                reject(error: "创建识别请求失败", completion: completion)
                return
            }

            recognitionRequest.shouldReportPartialResults = true  // 启用部分结果，以便实时检测语音

            // 配置音频会话 - 使用 playAndRecord category 和 measurement mode
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(
                .playAndRecord,
                mode: .measurement,
                options: [.defaultToSpeaker, .allowBluetoothA2DP]
            )
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            StructuredLogger.shared.debug("🎤 [Speech] Audio session configured, category: \(audioSession.category), mode: \(audioSession.mode)", category: .handler)

            // 设置音频输入 - 使用与语音识别兼容的格式
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            StructuredLogger.shared.debug("🎤 [Speech] Input format: \(recordingFormat)", category: .handler)

            // 直接使用硬件格式，但需要是线性PCM格式
            // Speech Recognition 支持多种格式，关键是 linear PCM
            guard recordingFormat.commonFormat == .pcmFormatFloat32 else {
                reject(error: "不支持的音频格式，需要 Float32 格式", completion: completion)
                return
            }

            // 标记识别开始
            isRecognizing = true

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }
            isTapInstalled = true

            audioEngine.prepare()

            // 启动音频引擎
            try audioEngine.start()
            StructuredLogger.shared.debug("🎤 [Speech] Audio engine started, isRunning: \(audioEngine.isRunning)", category: .handler)

            // 开始识别
            var finalResult = ""
            var hasFinalResult = false
            var lastPartialResult = ""

            recognitionTask = recognizer.recognitionTask(with: recognitionRequest, resultHandler: { [weak self] result, error in
                // 如果已经处理过最终结果，忽略后续回调
                if hasFinalResult {
                    StructuredLogger.shared.debug("🎤 [Speech] Already has final result, ignoring callback", category: .handler)
                    return
                }

                if let error = error {
                    let errorDesc = error.localizedDescription
                    StructuredLogger.shared.error("🎤 [Speech] Recognition error: \(errorDesc)", category: .handler)

                    // 检查是否是正常结束（用户停止或超时）
                    if errorDesc.contains("restart") || errorDesc.contains("cancelled") {
                        // 正常结束，使用最后一次的部分结果
                        let resultToUse = lastPartialResult.isEmpty ? finalResult : lastPartialResult
                        StructuredLogger.shared.debug("🎤 [Speech] Recognition ended normally, result: '\(resultToUse)'", category: .handler)

                        if !resultToUse.isEmpty {
                            hasFinalResult = true
                            self?.finishRecognition(success: true, text: resultToUse, language: recognizer.locale.identifier, completion: completion)
                        } else {
                            hasFinalResult = true
                            self?.finishRecognition(success: false, text: "未检测到语音输入，请检查麦克风权限并重试", language: nil, completion: completion)
                        }
                        return
                    }

                    // 真正的错误（不是 "No speech detected"，这个我们用超时处理）
                    if !errorDesc.contains("No speech detected") {
                        hasFinalResult = true
                        self?.finishRecognition(success: false, text: "识别错误: \(errorDesc)", language: nil, completion: completion)
                    }
                    return
                }

                if let result = result {
                    let transcription = result.bestTranscription.formattedString
                    StructuredLogger.shared.debug("🎤 [Speech] Got result, isFinal: \(result.isFinal), text: '\(transcription)'", category: .handler)

                    if !transcription.isEmpty {
                        lastPartialResult = transcription
                        finalResult = transcription

                        // 实时发送部分结果到 JavaScript（暂时不包含准确度）
                        self?.sendPartialResult(transcription, isFinal: result.isFinal, confidence: nil)
                    }

                    // 获得最终结果
                    if result.isFinal {
                        hasFinalResult = true
                        self?.timeoutTimer?.cancel()  // 取消超时定时器
                        self?.finishRecognition(success: true, text: finalResult, language: recognizer.locale.identifier, completion: completion)
                    }
                }
            })

            StructuredLogger.shared.debug("🎤 [Speech] Recognition task created, waiting for audio input...", category: .handler)

            // 设置超时定时器 - 给用户30秒时间说话
            let workItem = DispatchWorkItem { [weak self] in
                guard !hasFinalResult else { return }

                // 超时了，检查是否有部分结果
                if !finalResult.isEmpty {
                    hasFinalResult = true
                    self?.finishRecognition(success: true, text: finalResult, language: recognizer.locale.identifier, completion: completion)
                } else {
                    hasFinalResult = true
                    self?.finishRecognition(success: false, text: "录音超时，未检测到语音输入", language: nil, completion: completion)
                }
            }
            timeoutTimer = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + recognitionTimeout, execute: workItem)

        } catch {
            stopRecognitionInternal()
            reject(error: "启动音频引擎失败: \(error.localizedDescription)", completion: completion)
        }
    }

    private func finishRecognition(success: Bool, text: String, language: String?, completion: @escaping (Any) -> Void) {
        stopRecognitionInternal()

        if success {
            resolve([
                "text": text,
                "language": language ?? "zh-CN"
            ], completion: completion)
        } else {
            reject(error: text, completion: completion)
        }
    }

    private func stopRecognition(completion: @escaping (Any) -> Void) {
        stopRecognitionInternal()
        resolve(["message": "Speech recognition stopped"], completion: completion)
    }

    private func stopRecognitionInternal() {
        // 取消超时定时器
        timeoutTimer?.cancel()
        timeoutTimer = nil

        // 停止音频引擎
        if audioEngine.isRunning {
            audioEngine.stop()
        }

        // 安全地移除 tap（只在已安装时移除）
        if isTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            isTapInstalled = false
            StructuredLogger.shared.debug("🎤 [Speech] Tap removed", category: .handler)
        }

        // 清理识别资源
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil

        // 重置状态标志
        isRecognizing = false

        // 停用音频会话
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}
