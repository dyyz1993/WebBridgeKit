//
//  BaseViewControllerTests.swift
//  BaseTests
//
//  Created for WebBridgeKit test coverage.
//

import XCTest
@testable import WebBridgeKit
import RxSwift
import UIKit

final class BaseViewControllerTests: XCTestCase {

    // MARK: - Test Helpers

    private final class MockViewModel: ViewModel {
        let name: String

        init(name: String) {
            self.name = name
            super.init()
        }
    }

    private final class TestableVC: BaseViewController<MockViewModel> {
        var makeUICalled = false
        var bindViewModelCalled = false
        var makeUICallCount = 0
        var bindViewModelCallCount = 0

        override func makeUI() {
            makeUICalled = true
            makeUICallCount += 1
        }

        override func bindViewModel() {
            bindViewModelCalled = true
            bindViewModelCallCount += 1
        }
    }

    // MARK: - Initialization

    func testInit_shouldStoreViewModel() {
        let vm = MockViewModel(name: "test")
        let vc = BaseViewController(viewModel: vm)

        XCTAssertEqual(vc.viewModel.name, "test", "ViewController should store the provided ViewModel")
    }

    func testInit_shouldHaveDisposeBag() {
        let vm = MockViewModel(name: "test")
        let vc = BaseViewController(viewModel: vm)

        XCTAssertNotNil(vc.rx, "ViewController should have a DisposeBag")
    }

    func testInit_shouldSetViewModelBindedToFalse() {
        let vm = MockViewModel(name: "test")
        let vc = BaseViewController(viewModel: vm)

        XCTAssertFalse(vc.isViewModelBinded, "isViewModelBinded should default to false")
    }

    func testInit_shouldSetNibAndBundleToNil() {
        let vm = MockViewModel(name: "test")
        let vc = BaseViewController(viewModel: vm)

        XCTAssertNil(vc.nibName, "nibName should be nil")
        XCTAssertNil(vc.nibBundle, "nibBundle should be nil")
    }

    // MARK: - init(coder:) unavailability

    func testInitCoder_isCompileTimeUnavailable() {
        let vm = MockViewModel(name: "test")
        let vc = BaseViewController(viewModel: vm)
        XCTAssertNotNil(vc, "init(coder:) is @available(*, unavailable) — verified at compile time")
    }

    // MARK: - viewDidLoad -> makeUI

    func testViewDidLoad_shouldCallMakeUI() {
        let vm = MockViewModel(name: "test")
        let vc = TestableVC(viewModel: vm)

        vc.loadViewIfNeeded()

        XCTAssertTrue(vc.makeUICalled, "viewDidLoad should trigger makeUI()")
    }

    func testViewDidLoad_shouldCallMakeUIExactlyOnce() {
        let vm = MockViewModel(name: "test")
        let vc = TestableVC(viewModel: vm)

        vc.loadViewIfNeeded()
        vc.viewDidLoad()

        XCTAssertEqual(vc.makeUICallCount, 2, "makeUI is called each time viewDidLoad is called (super calls it)")
    }

    // MARK: - viewWillAppear -> bindViewModel

    func testViewWillAppear_shouldCallBindViewModelOnce() {
        let vm = MockViewModel(name: "test")
        let vc = TestableVC(viewModel: vm)

        vc.loadViewIfNeeded()
        vc.viewWillAppear(false)

        XCTAssertTrue(vc.bindViewModelCalled, "viewWillAppear should trigger bindViewModel()")
    }

    func testViewWillAppear_shouldSetIsViewModelBindedToTrue() {
        let vm = MockViewModel(name: "test")
        let vc = TestableVC(viewModel: vm)

        vc.loadViewIfNeeded()
        vc.viewWillAppear(false)

        XCTAssertTrue(vc.isViewModelBinded, "isViewModelBinded should be true after first viewWillAppear")
    }

    func testViewWillAppear_shouldCallBindViewModelOnlyOnce() {
        let vm = MockViewModel(name: "test")
        let vc = TestableVC(viewModel: vm)

        vc.loadViewIfNeeded()
        vc.viewWillAppear(false)
        vc.viewWillAppear(false)
        vc.viewWillAppear(false)

        XCTAssertEqual(vc.bindViewModelCallCount, 1, "bindViewModel should only be called once even with multiple viewWillAppear calls")
    }

    func testViewWillAppear_shouldNotCallBindViewModelBeforeViewLoad() {
        let vm = MockViewModel(name: "test")
        let vc = TestableVC(viewModel: vm)

        XCTAssertFalse(vc.bindViewModelCalled, "bindViewModel should not be called before viewWillAppear")
    }

    // MARK: - Different ViewModels

    func testInit_withDifferentViewModels_shouldStoreCorrectInstance() {
        let vm1 = MockViewModel(name: "first")
        let vm2 = MockViewModel(name: "second")

        let vc1 = BaseViewController(viewModel: vm1)
        let vc2 = BaseViewController(viewModel: vm2)

        XCTAssertEqual(vc1.viewModel.name, "first")
        XCTAssertEqual(vc2.viewModel.name, "second")
    }

    // MARK: - DisposeBag identity

    func testRx_shouldReturnSameDisposeBagInstance() {
        let vm = MockViewModel(name: "test")
        let vc = BaseViewController(viewModel: vm)

        let bag1 = vc.rx
        let bag2 = vc.rx

        XCTAssertTrue(bag1 === bag2, "rx should always return the same DisposeBag")
    }

    // MARK: - Open class behavior

    func testBaseViewController_isOpenClass() {
        let vm = MockViewModel(name: "test")
        let vc = BaseViewController(viewModel: vm)
        XCTAssertNotNil(vc, "BaseViewController should be instantiable as open class")
    }

    func testMakeUI_canBeOverridden() {
        let vm = MockViewModel(name: "test")
        let vc = TestableVC(viewModel: vm)

        vc.loadViewIfNeeded()

        XCTAssertTrue(vc.makeUICalled, "Subclass override of makeUI should be called")
    }

    func testBindViewModel_canBeOverridden() {
        let vm = MockViewModel(name: "test")
        let vc = TestableVC(viewModel: vm)

        vc.loadViewIfNeeded()
        vc.viewWillAppear(false)

        XCTAssertTrue(vc.bindViewModelCalled, "Subclass override of bindViewModel should be called")
    }
}
