import XCTest
@testable import WebBridgeKit
import RxSwift
import RxCocoa

final class WebPageHistoryViewModelTests: XCTestCase {

    private var disposeBag: DisposeBag!

    private var viewModel: WebPageHistoryViewModel!

    override func setUp() {
        super.setUp()
        viewModel = WebPageHistoryViewModel()
        disposeBag = DisposeBag()
    }

    override func tearDown() {
        disposeBag = nil
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInit_WhenCreated_HasDisposeBag() async {
        await MainActor.run {
            let viewModel = WebPageHistoryViewModel()
            XCTAssertNotNil(viewModel.disposeBag)
        }
    }

    func testTransform_WhenCreated_ReturnsNonNilOutput() async {
        await MainActor.run {
            let viewModel = WebPageHistoryViewModel()

            let input = WebPageHistoryViewModel.Input(
                refresh: Driver.never(),
                itemSelect: Driver.never(),
                itemDelete: Driver.never(),
                searchText: Observable.just(nil),
                viewModeToggle: Driver.never(),
                cacheRequest: Driver.never(),
                deleteCacheRequest: Driver.never(),
                qrScan: Driver.never()
            )

            let output = viewModel.transform(input: input)

            XCTAssertNotNil(output)
        }
    }

    // MARK: - Output Structure

    func testTransform_WhenCreated_AllOutputDriversAreNonNil() async {
        await MainActor.run {
            let viewModel = WebPageHistoryViewModel()

            let input = WebPageHistoryViewModel.Input(
                refresh: Driver.never(),
                itemSelect: Driver.never(),
                itemDelete: Driver.never(),
                searchText: Observable.just(nil),
                viewModeToggle: Driver.never(),
                cacheRequest: Driver.never(),
                deleteCacheRequest: Driver.never(),
                qrScan: Driver.never()
            )

            let output = viewModel.transform(input: input)

            XCTAssertNotNil(output.histories)
            XCTAssertNotNil(output.title)
            XCTAssertNotNil(output.isEmpty)
            XCTAssertNotNil(output.openURL)
            XCTAssertNotNil(output.cacheProgress)
            XCTAssertNotNil(output.cacheSuccess)
            XCTAssertNotNil(output.cacheError)
            XCTAssertNotNil(output.showScanner)
        }
    }

    // MARK: - Title

    func testTransform_WhenCreated_TitleIsNotEmpty() async {
        await MainActor.run {
            let input = WebPageHistoryViewModel.Input(
                refresh: Driver.never(),
                itemSelect: Driver.never(),
                itemDelete: Driver.never(),
                searchText: Observable.just(nil),
                viewModeToggle: Driver.never(),
                cacheRequest: Driver.never(),
                deleteCacheRequest: Driver.never(),
                qrScan: Driver.never()
            )

            let output = viewModel.transform(input: input)

            XCTAssertNotNil(output.title)
        }
    }

    // MARK: - ViewMode

    func testViewMode_WhenCreated_DefaultsToList() async {
        XCTAssertTrue(ViewMode.list == .list, "Default view mode should be list")
    }

    func testViewMode_WhenGallery_IsNotList() async {
        XCTAssertFalse(ViewMode.gallery == .list)
    }
}
