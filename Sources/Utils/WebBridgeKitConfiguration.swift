//
//  WebBridgeKitConfiguration.swift
//  WebBridgeKit
//
//  Created on 2025-01-30.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import AVFoundation

/// WebBridgeKit 全局配置
/// 集中管理框架中使用的魔法数字和常量
public struct WebBridgeKitConfiguration {

    // MARK: - 时间间隔配置

    /// 时间间隔相关配置
    public struct Timing {
        /// 动画时长（秒）
        public static let animationDuration: TimeInterval = 0.3
        public static let shortAnimationDuration: TimeInterval = 0.15
        public static let longAnimationDuration: TimeInterval = 0.5

        /// UI 响应延迟（秒）
        public static let uiResponseDelay: TimeInterval = 0.1
        public static let mediumDelay: TimeInterval = 0.5
        public static let longDelay: TimeInterval = 1.0
        public static let veryLongDelay: TimeInterval = 1.5
        public static let extendedDelay: TimeInterval = 2.0

        /// 网络请求超时（秒）
        public static let networkRequestTimeout: TimeInterval = 10.0
        public static let shortNetworkTimeout: TimeInterval = 5.0
        public static let longNetworkTimeout: TimeInterval = 30.0

        /// 缓存同步超时（秒）
        public static let cacheSyncTimeout: TimeInterval = 2.0
        public static let cacheSyncShortTimeout: TimeInterval = 1.0
    }

    // MARK: - 缓存配置

    /// 缓存相关配置
    public struct Cache {
        /// 最大缓存大小（字节）
        public static let maxCacheSize: Int64 = 500 * 1024 * 1024
        public static let maxCompressedCacheSize: Int64 = 500 * 1024 * 1024

        /// 单个文件最大大小（字节）
        public static let maxFileSize: Int = 50 * 1024 * 1024

        /// 缓存清理阈值（天数）
        public static let cleanupThresholdDays: TimeInterval = 7 * 24 * 60 * 60
        public static let shortCleanupThreshold: TimeInterval = 1 * 24 * 60 * 60
        public static let longCleanupThreshold: TimeInterval = 30 * 24 * 60 * 60

        /// 历史记录保留限制
        public static let maxHistoryCount: Int = 1000
        public static let defaultHistoryLimit: Int = 100

        /// 缓存命中率计算
        public static func calculateHitRate(_ hits: Int, _ total: Int) -> Double {
            return total > 0 ? Double(hits) / Double(total) : 0.0
        }
    }

    // MARK: - 音频配置

    /// 音频相关配置
    public struct Audio {
        /// 音频缓冲区大小
        public static let bufferSize: AVAudioFrameCount = 1024
        public static let largeBufferSize: AVAudioFrameCount = 2048
        public static let smallBufferSize: AVAudioFrameCount = 512

        /// 音频采样配置
        public static let defaultSampleRate: Double = 44100.0
        public static let defaultChannels: UInt32 = 1

        /// 音量级别
        public static let minVolume: Float = 0.0
        public static let maxVolume: Float = 1.0
        public static let defaultSensitivity: Float = 5.0
    }

    // MARK: - 手势配置

    /// 手势识别相关配置
    public struct Gesture {
        /// 下拉阈值（屏幕高度百分比）
        public static let pullThreshold: CGFloat = 0.2
        public static let smallPullThreshold: CGFloat = 0.15
        public static let largePullThreshold: CGFloat = 0.25

        /// 手势识别进度最大值
        public static let maxProgress: CGFloat = 1.0
        public static let progressScale: CGFloat = 1.0

        /// 眼部闭合阈值（用于 Face ID 面部识别）
        public static let eyeClosedThreshold: CGFloat = 0.2
        public static let eyeOpenThreshold: CGFloat = 0.5

        /// 长按最短时长（秒）
        public static let longPressMinimumDuration: TimeInterval = 0.5
    }

    // MARK: - 网络配置

    /// 网络相关配置
    public struct Network {
        /// 默认 User-Agent
        public static let defaultUserAgent: String = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

        /// HTTP 版本
        public static let httpVersion: String = "HTTP/1.1"

        /// 重试配置
        public static let maxRetries: Int = 3
        public static let retryDelay: TimeInterval = 0.5
        public static let longRetryDelay: TimeInterval = 1.0

        /// 连接超时
        public static let connectionTimeout: TimeInterval = 10.0
    }

    // MARK: - UI 配置

    /// UI 相关配置
    public struct UI {
        /// 模态弹窗默认尺寸（屏幕百分比）
        public static let modalWidthPercent: CGFloat = 0.8
        public static let modalHeightPercent: CGFloat = 0.8

        /// 圆角半径
        public static let defaultCornerRadius: CGFloat = 12.0
        public static let smallCornerRadius: CGFloat = 8.0
        public static let largeCornerRadius: CGFloat = 16.0

        /// 阴影配置
        public static let shadowOpacity: Float = 0.3
        public static let shadowRadius: CGFloat = 16.0
        public static let shadowOffsetVertical: CGFloat = 4.0

        /// 工具栏高度
        public static let toolbarHeight: CGFloat = 44.0
        public static let navigationBarHeight: CGFloat = 44.0

        /// 缩放级别
        public static let minimumZoomScale: CGFloat = 1.0
        public static let maximumZoomScale: CGFloat = 5.0
    }

    // MARK: - 媒体配置

    /// 媒体相关配置
    public struct Media {
        /// 图片选择限制
        public static let defaultPhotoLimit: Int = 5
        public static let singlePhotoLimit: Int = 1

        /// 联系人选择限制
        public static let defaultContactLimit: Int = 1

        /// 视频比特率
        public static let defaultVideoBitrate: Int = 1000000
    }

    // MARK: - 内存管理配置

    /// 内存管理相关配置
    public struct Memory {
        /// 内存单位换算
        public static let bytesPerKB: Int64 = 1024
        public static let bytesPerMB: Int64 = 1024 * 1024
        public static let bytesPerGB: Int64 = 1024 * 1024 * 1024

        /// KB 转 MB
        public static func kbToMB(_ kb: Int) -> Double {
            return Double(kb) / 1024.0
        }

        /// 字节转 MB
        public static func bytesToMB(_ bytes: Int64) -> Double {
            return Double(bytes) / Double(bytesPerMB)
        }
    }

    // MARK: - 调试配置

    /// 调试相关配置
    public struct Debug {
        /// 日志输出开关
        public static var isLoggingEnabled: Bool = true

        /// 性能监控开关
        public static var isPerformanceMonitoringEnabled: Bool = false

        /// 内存监控间隔（秒）
        public static let memoryMonitoringInterval: TimeInterval = 1.0
    }
}
