//
//  WebBridgeKitConfigurationTests.swift
//  UtilsTests
//

import XCTest
@testable import WebBridgeKit

final class WebBridgeKitConfigurationTests: XCTestCase {

    // MARK: - Timing

    func testTimingAnimationDuration() {
        XCTAssertEqual(WebBridgeKitConfiguration.Timing.animationDuration, 0.3)
        XCTAssertEqual(WebBridgeKitConfiguration.Timing.shortAnimationDuration, 0.15)
        XCTAssertEqual(WebBridgeKitConfiguration.Timing.longAnimationDuration, 0.5)
    }

    func testTimingDelays() {
        XCTAssertGreaterThan(WebBridgeKitConfiguration.Timing.uiResponseDelay, 0)
        XCTAssertGreaterThan(WebBridgeKitConfiguration.Timing.mediumDelay, WebBridgeKitConfiguration.Timing.uiResponseDelay)
        XCTAssertGreaterThan(WebBridgeKitConfiguration.Timing.longDelay, WebBridgeKitConfiguration.Timing.mediumDelay)
    }

    func testTimingNetworkTimeouts() {
        XCTAssertEqual(WebBridgeKitConfiguration.Timing.networkRequestTimeout, 10.0)
        XCTAssertEqual(WebBridgeKitConfiguration.Timing.shortNetworkTimeout, 5.0)
        XCTAssertEqual(WebBridgeKitConfiguration.Timing.longNetworkTimeout, 30.0)
    }

    func testTimingCacheSyncTimeout() {
        XCTAssertGreaterThan(WebBridgeKitConfiguration.Timing.cacheSyncTimeout, 0)
    }

    // MARK: - Cache

    func testCacheMaxSize() {
        let expectedMax: Int64 = 500 * 1024 * 1024
        XCTAssertEqual(WebBridgeKitConfiguration.Cache.maxCacheSize, expectedMax)
    }

    func testCacheMaxFileSize() {
        let expected: Int = 50 * 1024 * 1024
        XCTAssertEqual(WebBridgeKitConfiguration.Cache.maxFileSize, expected)
    }

    func testCacheMaxHistoryCount() {
        XCTAssertEqual(WebBridgeKitConfiguration.Cache.maxHistoryCount, 1000)
        XCTAssertEqual(WebBridgeKitConfiguration.Cache.defaultHistoryLimit, 100)
    }

    func testCacheCalculateHitRateWithValidData() {
        let rate = WebBridgeKitConfiguration.Cache.calculateHitRate(75, 100)
        XCTAssertEqual(rate, 0.75, accuracy: 0.001)
    }

    func testCacheCalculateHitRateWithZeroTotal() {
        let rate = WebBridgeKitConfiguration.Cache.calculateHitRate(10, 0)
        XCTAssertEqual(rate, 0.0)
    }

    func testCacheCalculateHitRateWithFullHits() {
        let rate = WebBridgeKitConfiguration.Cache.calculateHitRate(100, 100)
        XCTAssertEqual(rate, 1.0, accuracy: 0.001)
    }

    func testCacheCleanupThresholdDays() {
        let sevenDays: TimeInterval = 7 * 24 * 60 * 60
        XCTAssertEqual(WebBridgeKitConfiguration.Cache.cleanupThresholdDays, sevenDays)
    }

    // MARK: - Audio

    func testAudioBufferSize() {
        XCTAssertEqual(WebBridgeKitConfiguration.Audio.bufferSize, 1024)
        XCTAssertEqual(WebBridgeKitConfiguration.Audio.largeBufferSize, 2048)
        XCTAssertEqual(WebBridgeKitConfiguration.Audio.smallBufferSize, 512)
    }

    func testAudioSampleRate() {
        XCTAssertEqual(WebBridgeKitConfiguration.Audio.defaultSampleRate, 44100.0)
        XCTAssertEqual(WebBridgeKitConfiguration.Audio.defaultChannels, 1)
    }

    func testAudioVolumeRange() {
        XCTAssertEqual(WebBridgeKitConfiguration.Audio.minVolume, 0.0)
        XCTAssertEqual(WebBridgeKitConfiguration.Audio.maxVolume, 1.0)
        XCTAssertGreaterThan(WebBridgeKitConfiguration.Audio.defaultSensitivity, 0)
    }

    // MARK: - Gesture

    func testGesturePullThreshold() {
        XCTAssertGreaterThan(WebBridgeKitConfiguration.Gesture.pullThreshold, 0)
        XCTAssertLessThanOrEqual(WebBridgeKitConfiguration.Gesture.pullThreshold, 1.0)
    }

    func testGestureLongPressDuration() {
        XCTAssertGreaterThan(WebBridgeKitConfiguration.Gesture.longPressMinimumDuration, 0)
    }

    func testGestureMaxProgress() {
        XCTAssertEqual(WebBridgeKitConfiguration.Gesture.maxProgress, 1.0)
    }

    // MARK: - Network

    func testNetworkDefaultUserAgent() {
        XCTAssertFalse(WebBridgeKitConfiguration.Network.defaultUserAgent.isEmpty)
        XCTAssertTrue(WebBridgeKitConfiguration.Network.defaultUserAgent.contains("Mozilla"))
    }

    func testNetworkRetryConfig() {
        XCTAssertEqual(WebBridgeKitConfiguration.Network.maxRetries, 3)
        XCTAssertGreaterThan(WebBridgeKitConfiguration.Network.retryDelay, 0)
    }

    func testNetworkConnectionTimeout() {
        XCTAssertGreaterThan(WebBridgeKitConfiguration.Network.connectionTimeout, 0)
    }

    // MARK: - UI

    func testUIModalSizes() {
        XCTAssertGreaterThan(WebBridgeKitConfiguration.UI.modalWidthPercent, 0)
        XCTAssertLessThanOrEqual(WebBridgeKitConfiguration.UI.modalWidthPercent, 1.0)
        XCTAssertGreaterThan(WebBridgeKitConfiguration.UI.modalHeightPercent, 0)
    }

    func testUICornerRadii() {
        XCTAssertGreaterThan(WebBridgeKitConfiguration.UI.defaultCornerRadius, 0)
        XCTAssertGreaterThan(WebBridgeKitConfiguration.UI.smallCornerRadius, 0)
        XCTAssertGreaterThan(WebBridgeKitConfiguration.UI.largeCornerRadius, WebBridgeKitConfiguration.UI.defaultCornerRadius)
    }

    func testUIToolbarHeight() {
        XCTAssertEqual(WebBridgeKitConfiguration.UI.toolbarHeight, 44.0)
    }

    func testUIZoomScales() {
        XCTAssertLessThanOrEqual(WebBridgeKitConfiguration.UI.minimumZoomScale, WebBridgeKitConfiguration.UI.maximumZoomScale)
    }

    // MARK: - Media

    func testMediaPhotoLimit() {
        XCTAssertEqual(WebBridgeKitConfiguration.Media.defaultPhotoLimit, 5)
        XCTAssertEqual(WebBridgeKitConfiguration.Media.singlePhotoLimit, 1)
    }

    // MARK: - Memory

    func testMemoryConversionKBToMB() {
        let result = WebBridgeKitConfiguration.Memory.kbToMB(1024)
        XCTAssertEqual(result, 1.0, accuracy: 0.001)
    }

    func testMemoryConversionBytesToMB() {
        let oneMB: Int64 = 1024 * 1024
        let result = WebBridgeKitConfiguration.Memory.bytesToMB(oneMB)
        XCTAssertEqual(result, 1.0, accuracy: 0.001)
    }

    func testMemoryBytesPerKB() {
        XCTAssertEqual(WebBridgeKitConfiguration.Memory.bytesPerKB, 1024)
    }

    func testMemoryBytesPerMB() {
        XCTAssertEqual(WebBridgeKitConfiguration.Memory.bytesPerMB, 1024 * 1024)
    }

    func testMemoryBytesPerGB() {
        XCTAssertEqual(WebBridgeKitConfiguration.Memory.bytesPerGB, 1024 * 1024 * 1024)
    }

    // MARK: - Debug

    func testDebugLoggingEnabled() {
        XCTAssertTrue(WebBridgeKitConfiguration.Debug.isLoggingEnabled)
    }
}
