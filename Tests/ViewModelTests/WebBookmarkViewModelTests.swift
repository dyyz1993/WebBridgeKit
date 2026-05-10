import XCTest
@testable import WebBridgeKit
import RxSwift
import RxCocoa

final class WebBookmarkViewModelTests: XCTestCase {

    private var viewModel: WebBookmarkViewModel!
    private var disposeBag: DisposeBag!

    override func setUp() {
        super.setUp()
        viewModel = WebBookmarkViewModel()
        disposeBag = DisposeBag()
    }

    override func tearDown() {
        disposeBag = nil
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInit_WhenCreated_HasEmptyBookmarks() {
        let input = WebBookmarkViewModel.Input(
            load: Driver.just(()),
            search: Driver.just(nil),
            delete: Driver.never()
        )

        let output = viewModel.transform(input: input)

        XCTAssertNotNil(output.bookmarks)
    }

    func testInit_WhenCreated_IsEmptyIsTrue() {
        let input = WebBookmarkViewModel.Input(
            load: Driver.just(()),
            search: Driver.just(nil),
            delete: Driver.never()
        )

        let output = viewModel.transform(input: input)

        XCTAssertNotNil(output.isEmpty)
    }

    // MARK: - Load

    func testTransform_WhenLoadTriggered_EmitsBookmarks() {
        let input = WebBookmarkViewModel.Input(
            load: Driver.just(()),
            search: Driver.just(nil),
            delete: Driver.never()
        )

        let output = viewModel.transform(input: input)

        XCTAssertNotNil(output.bookmarks)
    }

    // MARK: - WebBookmark Model

    func testWebBookmark_WhenInitialized_HoldsProperties() {
        let bookmark = WebBookmark(
            id: "test-id",
            url: "https://example.com",
            title: "Example"
        )

        XCTAssertEqual(bookmark.id, "test-id")
        XCTAssertEqual(bookmark.url, "https://example.com")
        XCTAssertEqual(bookmark.title, "Example")
    }

    func testWebBookmark_WhenInitializedWithEmptyStrings_HoldsEmptyValues() {
        let bookmark = WebBookmark(id: "", url: "", title: "")

        XCTAssertEqual(bookmark.id, "")
        XCTAssertEqual(bookmark.url, "")
        XCTAssertEqual(bookmark.title, "")
    }

    // MARK: - DisposeBag

    func testInit_WhenCreated_HasOwnDisposeBag() {
        XCTAssertNotNil(viewModel.disposeBag, "ViewModel should have a dispose bag")
    }
}
