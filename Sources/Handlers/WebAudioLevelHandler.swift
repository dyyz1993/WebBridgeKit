//
//  WebAudioLevelHandler.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-13.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import AVFoundation
import Foundation
import WebKit

// Framework imports

/// 实时音频音量监控处理器
/// 用于游戏控制：通过声音大小控制角色跳跃高度
public class WebAudioLevelHandler: BaseWebNativeHandler {

    private var audioEngine: AVAudioEngine?
    private var levelTimer: DispatchSourceTimer?
    private var isMonitoring = false

    // 当前音量值 (0.0 - 1.0)
    private var currentLevel: Float = 0

    // 音量放大倍数（可配置，默认 5.0 降低基础灵敏度）
    private var levelMultiplier: Float = 5.0

    /**
     * 处理音频监控请求
     * - Parameters:
     *   - body: 请求参数字典 (action, fps, sensitivity)
     *   - completion: 结果回调
     */
    public override func handle(body: [String: Any], completion: @escaping (Any) -> Void) {
        // 从 params 中获取参数，兼容直接在 body 中传参的情况
        let params = body["params"] as? [String: Any] ?? body
        let action = params["action"] as? String ?? "start"

        // 兼容从 JS 传递过来的数字类型（JS 数字在桥接时通常表现为 NSNumber）
        let fps = (params["fps"] as? NSNumber)?.intValue ?? 30
        let sensitivity = (params["sensitivity"] as? NSNumber)?.floatValue ?? 5.0

        switch action {
        case "start":
            startMonitoring(fps: fps, sensitivity: sensitivity, completion: completion)
        case "stop":
            stopMonitoring(completion: completion)
        case "setSensitivity":
            setSensitivity(sensitivity, completion: completion)
        default:
            reject(error: "Unknown action: \(action)", completion: completion)
        }
    }

    /**
     * 开始监听麦克风音量
     * - Parameters:
     *   - fps: 上报频率
     *   - sensitivity: 灵敏度
     *   - completion: 结果回调
     */
    private func startMonitoring(fps: Int, sensitivity: Float, completion: @escaping (Any) -> Void) {
        // 检查权限
        let status = AVAudioSession.sharedInstance().recordPermission
        if status == .denied {
            self.rejectPermissionDenied(type: .microphone, status: .denied, completion: completion)
            return
        } else if status == .undetermined {
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                self?.runOnMainThread {
                    if granted {
                        self?.startMonitoring(fps: fps, sensitivity: sensitivity, completion: completion)
                    } else {
                        self?.rejectPermissionDenied(type: .microphone, status: .denied, completion: completion)
                    }
                }
            }
            return
        }

        // 设置灵敏度
        self.levelMultiplier = sensitivity

        // 防止重复启动
        guard !isMonitoring else {
            reject(error: "Audio monitoring is already running", completion: completion)
            return
        }

        runOnMainThread { [weak self] in
            guard let self = self else {
                return
            }

            do {
                // 配置音频会话
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(
                    .playAndRecord,
                    mode: .default,
                    options: [.defaultToSpeaker, .allowBluetoothA2DP]
                )
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

                print("🎤 [AudioLevel] Audio session configured")

                // 创建音频引擎
                self.audioEngine = AVAudioEngine()
                guard let inputNode = self.audioEngine?.inputNode else {
                    self.isMonitoring = false
                    self.reject(error: "Failed to get audio input node", completion: completion)
                    return
                }
                let format = inputNode.outputFormat(forBus: 0)

                print("🎤 [AudioLevel] Audio format: \(format)")

                // 安装音频 tap - 实时处理音频数据
                inputNode.installTap(onBus: 0, bufferSize: WebBridgeKitConfiguration.Audio.bufferSize, format: format) { [weak self] buffer, _ in
                    self?.processAudioBuffer(buffer)
                }

                // 在某些情况下需要确保 inputNode 已经连接
                self.audioEngine?.prepare()

                // 启动音频引擎
                try self.audioEngine?.start()
                self.isMonitoring = true

                print("🎤 [AudioLevel] Audio engine started")

                // 启动定时器发送结果
                self.startTimer(fps: fps)

                self.resolve(["message": "Monitoring started"], completion: completion)

            } catch {
                self.isMonitoring = false
                self.audioEngine?.stop()
                self.audioEngine?.inputNode.removeTap(onBus: 0)
                self.audioEngine = nil
                self.reject(error: "Failed to start audio engine: \(error.localizedDescription)", completion: completion)
            }
        }
    }

    /**
     * 处理音频缓冲区，计算 RMS 音量
     * - Parameter buffer: 音频缓冲区
     */
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = UInt32(buffer.frameLength)

        var sum: Float = 0
        for i in 0..<Int(frameLength) {
            sum += channelData[i] * channelData[i]
        }

        let rms = sqrt(sum / Float(frameLength))
        // 使用灵敏度进行缩放，并限制在 0-1 之间
        self.currentLevel = min(1.0, rms * levelMultiplier)
    }

    /**
     * 启动定时器，按指定频率向 JS 发送音量数据
     * - Parameter fps: 每秒发送次数
     */
    private func startTimer(fps: Int) {
        levelTimer?.cancel()

        let interval = 1.0 / Double(max(1, fps))
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        timer.schedule(deadline: .now(), repeating: interval)

        timer.setEventHandler { [weak self] in
            guard let self = self, self.isMonitoring else { return }
            self.sendLevelToJS()
        }

        self.levelTimer = timer
        timer.resume()
    }

    /**
     * 通过 WebView 执行 JS 回调上报音量
     */
    private func sendLevelToJS() {
        // 使用统一的事件发送机制
        sendEventToJS(event: "onAudioLevelChange", data: ["level": currentLevel])

        // 同时保留旧的直接调用方式，确保最大兼容性
        let jsCode = "if(window.onAudioLevelChange) { window.onAudioLevelChange(\(currentLevel)); } else if(window.onAudioLevel) { window.onAudioLevel(\(currentLevel)); }"

        runOnMainThread { [weak self] in
            self?.webView?.evaluateJavaScript(jsCode)
        }
    }

    /**
     * 停止监听麦克风
     * - Parameter completion: 结果回调
     */
    private func stopMonitoring(completion: @escaping (Any) -> Void) {
        runOnMainThread { [weak self] in
            guard let self = self else { return }

            self.levelTimer?.cancel()
            self.levelTimer = nil

            self.audioEngine?.stop()
            self.audioEngine?.inputNode.removeTap(onBus: 0)
            self.audioEngine = nil

            self.isMonitoring = false

            self.resolve(["message": "Monitoring stopped"], completion: completion)
        }
    }

    /**
     * 动态调整音量灵敏度
     * - Parameters:
     *   - sensitivity: 灵敏度倍数
     *   - completion: 结果回调
     */
    private func setSensitivity(_ sensitivity: Float, completion: @escaping (Any) -> Void) {
        self.levelMultiplier = sensitivity
        resolve(["sensitivity": sensitivity], completion: completion)
    }
}
