import XCTest
@testable import WebBridgeKit
import RxSwift
import RxCocoa

final class CacheResourceViewModelSelectionTests: XCTestCase {

    private var viewModel: CacheResourceViewModel!
    private var disposeBag: DisposeBag!

    override func setUp() async throws {
        try await super.setUp()
        viewModel = CacheResourceViewModel()
        disposeBag = DisposeBag()
    }

    override func tearDown() async throws {
        disposeBag = nil
        viewModel = nil
        try await super.tearDown()
    }

    // MARK: - toggleSelection

    func testToggleSelection_WhenNewKey_AddsToSelection() {
        viewModel.toggleSelection(key: "resource-a")

        XCTAssertTrue(viewModel.isSelected(key: "resource-a"))
    }

    func testToggleSelection_WhenSameKeyToggledTwice_RemovesFromSelection() {
        viewModel.toggleSelection(key: "resource-a")
        viewModel.toggleSelection(key: "resource-a")

        XCTAssertFalse(viewModel.isSelected(key: "resource-a"))
    }

    func testToggleSelection_WhenMultipleKeys_AllTrackedIndependently() {
        viewModel.toggleSelection(key: "key-1")
        viewModel.toggleSelection(key: "key-2")
        viewModel.toggleSelection(key: "key-3")

        XCTAssertTrue(viewModel.isSelected(key: "key-1"))
        XCTAssertTrue(viewModel.isSelected(key: "key-2"))
        XCTAssertTrue(viewModel.isSelected(key: "key-3"))
    }

    func testToggleSelection_WhenOneKeyDeselected_OthersRemainSelected() {
        viewModel.toggleSelection(key: "key-1")
        viewModel.toggleSelection(key: "key-2")
        viewModel.toggleSelection(key: "key-1")

        XCTAssertFalse(viewModel.isSelected(key: "key-1"))
        XCTAssertTrue(viewModel.isSelected(key: "key-2"))
    }

    // MARK: - isSelected

    func testIsSelected_WhenNoSelections_ReturnsFalse() {
        XCTAssertFalse(viewModel.isSelected(key: "any-key"))
    }

    func testIsSelected_WhenKeyNotSelected_ReturnsFalse() {
        viewModel.toggleSelection(key: "selected-key")

        XCTAssertFalse(viewModel.isSelected(key: "unselected-key"))
    }

    // MARK: - deselectAllResources

    func testDeselectAllResources_WhenCalled_ClearsAllSelections() {
        viewModel.toggleSelection(key: "a")
        viewModel.toggleSelection(key: "b")
        viewModel.toggleSelection(key: "c")

        viewModel.deselectAllResources()

        XCTAssertFalse(viewModel.isSelected(key: "a"))
        XCTAssertFalse(viewModel.isSelected(key: "b"))
        XCTAssertFalse(viewModel.isSelected(key: "c"))
    }

    func testDeselectAllResources_WhenNothingSelected_DoesNotCrash() {
        viewModel.deselectAllResources()

        XCTAssertFalse(viewModel.isSelected(key: "any"))
    }

    // MARK: - deselectAllResources publishes selectedCount

    func testDeselectAllResources_WhenCalled_EmitsZeroCount() {
        let expectation = expectation(description: "selectedCount emitted")

        viewModel.toggleSelection(key: "a")

        let input = CacheResourceViewModel.Input(
            loadResources: Driver.never(),
            selectAll: Driver.never(),
            deselectAll: Driver.just(()),
            deleteSelected: Driver.never(),
            clearAll: Driver.never(),
            itemDelete: Driver.never()
        )

        let output = viewModel.transform(input: input)

        output.selectedCount
            .drive(onNext: { count in
                if count == 0 {
                    expectation.fulfill()
                }
            })
            .disposed(by: disposeBag)

        waitForExpectations(timeout: 2.0)
    }
}
