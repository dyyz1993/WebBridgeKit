import XCTest
@testable import WebBridgeKit
import RxSwift
import RxCocoa

final class WebBookmarkViewModelTests: XCTestCase {

    private var viewModel: WebBookmarkViewModel!
    private var disposeBag: DisposeBag!

    override func setUp() async throws {
        try await super.setUp()
        viewModel = WebBookmarkViewModel()
        disposeBag = DisposeBag()
    }

    override func tearDown() async throws {
        disposeBag = nil
        viewModel = nil
        try await super.tearDown()
    }

    // MARK: - Initial State

    func testInit_WhenCreated_HasEmptyBookmarks() {
        let expectation = expectation(description: "Initial bookmarks loaded")

        let input = WebBookmarkViewModel.Input(
            load: Driver.just(()),
            search: Driver.just(nil),
            delete: Driver.never()
        )

        let output = viewModel.transform(input: input)

        output.bookmarks
            .drive(onNext: { bookmarks in
                XCTAssertTrue(bookmarks.isEmpty, "Bookmarks should be empty initially")
                expectation.fulfill()
            })
            .disposed(by: disposeBag)

        waitForExpectations(timeout: 2.0)
    }

    func testInit_WhenCreated_IsEmptyIsTrue() {
        let expectation = expectation(description: "isEmpty check")

        let input = WebBookmarkViewModel.Input(
            load: Driver.just(()),
            search: Driver.just(nil),
            delete: Driver.never()
        )

        let output = viewModel.transform(input: input)

        output.isEmpty
            .drive(onNext: { isEmpty in
                XCTAssertTrue(isEmpty, "isEmpty should be true when no bookmarks")
                expectation.fulfill()
            })
            .disposed(by: disposeBag)

        waitForExpectations(timeout: 2.0)
    }

    // MARK: - Load

    func testTransform_WhenLoadTriggered_EmitsBookmarks() {
        let expectation = expectation(description: "Bookmarks emitted")

        let input = WebBookmarkViewModel.Input(
            load: Driver.just(()),
            search: Driver.just(nil),
            delete: Driver.never()
        )

        let output = viewModel.transform(input: input)

        output.bookmarks
            .drive(onNext: { _ in
                expectation.fulfill()
            })
            .disposed(by: disposeBag)

        waitForExpectations(timeout: 2.0)
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
