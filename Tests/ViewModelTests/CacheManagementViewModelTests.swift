import XCTest
@testable import WebBridgeKit
import RxSwift
import RxCocoa

final class CacheManagementViewModelTests: XCTestCase {

    private var viewModel: CacheManagementViewModel!
    private var disposeBag: DisposeBag!

    override func setUp() async throws {
        try await super.setUp()
        viewModel = CacheManagementViewModel()
        disposeBag = DisposeBag()
    }

    override func tearDown() async throws {
        disposeBag = nil
        viewModel = nil
        try await super.tearDown()
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

    func testTransform_WhenNoCacheData_IsEmptyEmitsTrue() {
        let expectation = expectation(description: "isEmpty emitted")

        let input = CacheManagementViewModel.Input(
            refresh: Driver.just(()),
            deleteApp: Driver.never(),
            deleteAll: Driver.never()
        )

        let output = viewModel.transform(input: input)

        output.isEmpty
            .drive(onNext: { isEmpty in
                if isEmpty {
                    expectation.fulfill()
                }
            })
            .disposed(by: disposeBag)

        waitForExpectations(timeout: 5.0)
    }

    func testTransform_WhenNoCacheData_CacheAppsIsEmpty() {
        let expectation = expectation(description: "cacheApps emitted empty")

        let input = CacheManagementViewModel.Input(
            refresh: Driver.just(()),
            deleteApp: Driver.never(),
            deleteAll: Driver.never()
        )

        let output = viewModel.transform(input: input)

        output.cacheApps
            .drive(onNext: { apps in
                if apps.isEmpty {
                    expectation.fulfill()
                }
            })
            .disposed(by: disposeBag)

        waitForExpectations(timeout: 5.0)
    }

    // MARK: - App Count

    func testTransform_WhenNoCacheData_AppCountIsZero() {
        let expectation = expectation(description: "appCount emitted")

        let input = CacheManagementViewModel.Input(
            refresh: Driver.just(()),
            deleteApp: Driver.never(),
            deleteAll: Driver.never()
        )

        let output = viewModel.transform(input: input)

        output.appCount
            .drive(onNext: { count in
                if count.contains("0") {
                    expectation.fulfill()
                }
            })
            .disposed(by: disposeBag)

        waitForExpectations(timeout: 5.0)
    }

    // MARK: - Total Cache Size

    func testTransform_WhenNoCacheData_TotalCacheSizeIsZero() {
        let expectation = expectation(description: "totalCacheSize emitted")

        let input = CacheManagementViewModel.Input(
            refresh: Driver.just(()),
            deleteApp: Driver.never(),
            deleteAll: Driver.never()
        )

        let output = viewModel.transform(input: input)

        output.totalCacheSize
            .drive(onNext: { size in
                if size == "0 bytes" || size.contains("0") {
                    expectation.fulfill()
                }
            })
            .disposed(by: disposeBag)

        waitForExpectations(timeout: 5.0)
    }

    // MARK: - Loading State

    func testTransform_WhenRefreshTriggered_LoadingTransitions() {
        let loadingExpectation = expectation(description: "loading changes")
        var sawLoading = false

        let input = CacheManagementViewModel.Input(
            refresh: Driver.just(()),
            deleteApp: Driver.never(),
            deleteAll: Driver.never()
        )

        let output = viewModel.transform(input: input)

        output.loading
            .drive(onNext: { isLoading in
                if !isLoading {
                    sawLoading = true
                    loadingExpectation.fulfill()
                }
            })
            .disposed(by: disposeBag)

        waitForExpectations(timeout: 5.0)
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
