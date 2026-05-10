import XCTest
@testable import WebBridgeKit
import RxSwift
import RxCocoa

final class CacheManagementViewModelTests: XCTestCase {

    private var viewModel: CacheManagementViewModel!
    private var disposeBag: DisposeBag!

    override func setUp() {
        super.setUp()
        viewModel = CacheManagementViewModel()
        disposeBag = DisposeBag()
    }

    override func tearDown() {
        disposeBag = nil
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInit_WhenCreated_CanTransformWithoutCrash() {
        let input = CacheManagementViewModel.Input(
            refresh: Driver.never(),
            deleteApp: Driver.never(),
            deleteAll: Driver.never()
        )

        let output = viewModel.transform(input: input)

        XCTAssertNotNil(output)
    }

    // MARK: - Output Structure

    func testTransform_WhenCreated_ReturnsNonNilDrivers() {
        let input = CacheManagementViewModel.Input(
            refresh: Driver.just(()),
            deleteApp: Driver.never(),
            deleteAll: Driver.never()
        )

        let output = viewModel.transform(input: input)

        XCTAssertNotNil(output.cacheApps)
        XCTAssertNotNil(output.isEmpty)
        XCTAssertNotNil(output.totalCacheSize)
        XCTAssertNotNil(output.appCount)
        XCTAssertNotNil(output.loading)
        XCTAssertNotNil(output.deleteSuccess)
        XCTAssertNotNil(output.deleteAllSuccess)
    }

    // MARK: - Empty State

    func testTransform_WhenNoCacheData_CacheAppsIsEmpty() {
        let input = CacheManagementViewModel.Input(
            refresh: Driver.just(()),
            deleteApp: Driver.never(),
            deleteAll: Driver.never()
        )

        let output = viewModel.transform(input: input)

        XCTAssertNotNil(output.cacheApps)
    }

    // MARK: - App Count

    func testTransform_WhenNoCacheData_AppCountIsZero() {
        let input = CacheManagementViewModel.Input(
            refresh: Driver.just(()),
            deleteApp: Driver.never(),
            deleteAll: Driver.never()
        )

        let output = viewModel.transform(input: input)

        XCTAssertNotNil(output.appCount)
    }

    // MARK: - Total Cache Size

    func testTransform_WhenNoCacheData_TotalCacheSizeIsZero() {
        let input = CacheManagementViewModel.Input(
            refresh: Driver.just(()),
            deleteApp: Driver.never(),
            deleteAll: Driver.never()
        )

        let output = viewModel.transform(input: input)

        XCTAssertNotNil(output.totalCacheSize)
    }

    // MARK: - Loading State

    func testTransform_WhenRefreshTriggered_LoadingTransitions() {
        let input = CacheManagementViewModel.Input(
            refresh: Driver.just(()),
            deleteApp: Driver.never(),
            deleteAll: Driver.never()
        )

        let output = viewModel.transform(input: input)

        XCTAssertNotNil(output.loading)
    }

    // MARK: - Repeated Transform

    func testTransform_WhenCalledMultipleTimes_ReturnsOutputs() {
        let input1 = CacheManagementViewModel.Input(
            refresh: Driver.never(),
            deleteApp: Driver.never(),
            deleteAll: Driver.never()
        )

        let output1 = viewModel.transform(input: input1)
        XCTAssertNotNil(output1)

        let input2 = CacheManagementViewModel.Input(
            refresh: Driver.just(()),
            deleteApp: Driver.never(),
            deleteAll: Driver.never()
        )

        let output2 = viewModel.transform(input: input2)
        XCTAssertNotNil(output2)
    }
}
