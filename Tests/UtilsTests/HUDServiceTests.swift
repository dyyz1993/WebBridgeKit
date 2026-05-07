//
//  HUDServiceTests.swift
//  UtilsTests
//

import XCTest
@testable import WebBridgeKit

final class HUDServiceTests: XCTestCase {

    private var hud: HUDService!

    override func setUp() {
        super.setUp()
        hud = HUDService.shared
    }

    override func tearDown() {
        hud.dismiss()
        super.tearDown()
    }

    // MARK: - Singleton

    func testSharedSingletonIsSameInstance() {
        let a = HUDService.shared
        let b = HUDService.shared
        XCTAssertTrue(a === b)
    }

    // MARK: - Show

    func testShowWithoutStatus() {
        hud.show()
    }

    func testShowWithStatus() {
        hud.show("Loading...")
    }

    // MARK: - Dismiss

    func testDismissWithoutShowDoesNotCrash() {
        hud.dismiss()
    }

    func testDismissAfterShow() {
        hud.show("Test")
        hud.dismiss()
    }

    // MARK: - Show Success

    func testShowSuccess() {
        hud.showSuccess(withStatus: "Operation completed")
    }

    func testShowSuccessWithEmptyStatus() {
        hud.showSuccess(withStatus: "")
    }

    // MARK: - Show Error

    func testShowError() {
        hud.showError(withStatus: "Something went wrong")
    }

    func testShowErrorWithEmptyStatus() {
        hud.showError(withStatus: "")
    }

    // MARK: - Show Info

    func testShowInfo() {
        hud.showInfo(withStatus: "Information")
    }

    func testShowInfoWithEmptyStatus() {
        hud.showInfo(withStatus: "")
    }

    // MARK: - Show Progress

    func testShowProgressZero() {
        hud.showProgress(0.0, status: "Starting")
    }

    func testShowProgressHalf() {
        hud.showProgress(0.5, status: "Halfway")
    }

    func testShowProgressFull() {
        hud.showProgress(1.0, status: "Complete")
    }

    func testShowProgressWithoutStatus() {
        hud.showProgress(0.75)
    }

    // MARK: - Set Status

    func testSetStatus() {
        hud.show("Initial")
        hud.setStatus("Updated")
    }

    func testSetStatusWithoutShow() {
        hud.setStatus("No HUD shown")
    }

    // MARK: - Dismiss with Delay

    func testDismissWithDelay() {
        hud.show("Will dismiss")
        hud.dismiss(withDelay: 0.1)
    }

    func testDismissWithZeroDelay() {
        hud.show("Instant dismiss")
        hud.dismiss(withDelay: 0)
    }

    // MARK: - Sequential Operations

    func testShowDismissShowAgain() {
        hud.show("First")
        hud.dismiss()
        hud.show("Second")
        hud.dismiss()
    }

    func testShowDifferentTypesSequentially() {
        hud.show("Loading")
        hud.showSuccess(withStatus: "Done")
        hud.showError(withStatus: "Error")
        hud.showInfo(withStatus: "Info")
        hud.dismiss()
    }

    // MARK: - Multiple Dismiss

    func testMultipleDismissDoesNotCrash() {
        hud.show("Test")
        hud.dismiss()
        hud.dismiss()
        hud.dismiss()
    }
}
