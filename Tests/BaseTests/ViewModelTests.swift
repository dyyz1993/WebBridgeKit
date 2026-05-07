//
//  ViewModelTests.swift
//  BaseTests
//
//  Created for WebBridgeKit test coverage.
//

import XCTest
@testable import WebBridgeKit
import RxSwift

final class ViewModelTests: XCTestCase {

    // MARK: - Initialization

    func testViewModel_init_shouldHaveRxDisposeBag() {
        let viewModel = ViewModel()
        XCTAssertNotNil(viewModel.rx, "ViewModel should have a non-nil DisposeBag")
    }

    func testViewModel_init_shouldBeNSObjectSubclass() {
        let viewModel = ViewModel()
        XCTAssertTrue(viewModel is NSObject, "ViewModel should be an NSObject subclass")
    }

    func testViewModel_init_shouldHaveDefaultValues() {
        let viewModel = ViewModel()
        XCTAssertNotNil(viewModel.rx, "DisposeBag should be initialized by default")
    }

    // MARK: - DisposeBag behavior

    func testViewModel_rx_shouldBeSameInstanceOnRepeatedAccess() {
        let viewModel = ViewModel()
        let first = viewModel.rx
        let second = viewModel.rx
        XCTAssertTrue(first === second, "rx property should return the same DisposeBag instance")
    }

    // MARK: - Subclassing

    func testViewModel_canBeSubclassed() {
        final class TestViewModel: ViewModel {
            var testProperty: String

            init(testProperty: String) {
                self.testProperty = testProperty
                super.init()
            }
        }

        let vm = TestViewModel(testProperty: "hello")
        XCTAssertEqual(vm.testProperty, "hello")
        XCTAssertNotNil(vm.rx, "Subclassed ViewModel should retain DisposeBag")
    }

    func testViewModel_subclassShouldInheritRx() {
        final class AnotherViewModel: ViewModel {}

        let vm = AnotherViewModel()
        let bag = vm.rx
        XCTAssertNotNil(bag, "Subclass should inherit rx DisposeBag")
    }
}
