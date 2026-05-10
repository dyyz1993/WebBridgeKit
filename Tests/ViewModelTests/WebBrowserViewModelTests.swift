import XCTest
@testable import WebBridgeKit
import RxSwift
import RxCocoa

final class WebBrowserViewModelTests: XCTestCase {

    private var disposeBag: DisposeBag!

    override func setUp() {
        super.setUp()
        disposeBag = DisposeBag()
    }

    override func tearDown() {
        disposeBag = nil
        super.tearDown()
    }

    // MARK: - Initialization

    func testInit_WhenNoURL_InitialURLIsNil() {
        let viewModel = WebBrowserViewModel()

        XCTAssertNil(viewModel.initialURL)
    }

    func testInit_WhenURLProvided_InitialURLIsSet() {
        let url = URL(string: "https://example.com")!
        let viewModel = WebBrowserViewModel(url: url)

        XCTAssertEqual(viewModel.initialURL, url)
    }

    func testInit_WhenCreated_HasDisposeBag() {
        let viewModel = WebBrowserViewModel()

        XCTAssertNotNil(viewModel.disposeBag)
    }

    // MARK: - getWebView

    func testGetWebView_WhenCalled_ReturnsWebView() {
        let viewModel = WebBrowserViewModel()

        let webView = viewModel.getWebView()

        XCTAssertNotNil(webView)
    }

    func testGetWebView_WhenCalledMultipleTimes_ReturnsSameInstance() {
        let viewModel = WebBrowserViewModel()

        let webView1 = viewModel.getWebView()
        let webView2 = viewModel.getWebView()

        XCTAssertTrue(webView1 === webView2, "Should return the same WKWebView instance")
    }

    // MARK: - Transform

    func testTransform_WhenCreated_ReturnsNonNilOutput() {
        let viewModel = WebBrowserViewModel()

        let input = WebBrowserViewModel.Input(
            loadURL: Driver.never(),
            goBack: Driver.never(),
            goForward: Driver.never(),
            reload: Driver.never(),
            stopLoading: Driver.never(),
            bookmarkToggle: Driver.never(),
            menuTap: Driver.never()
        )

        let output = viewModel.transform(input: input)

        XCTAssertNotNil(output)
    }

    func testTransform_WhenCreated_AllOutputDriversAreNonNil() {
        let viewModel = WebBrowserViewModel()

        let input = WebBrowserViewModel.Input(
            loadURL: Driver.never(),
            goBack: Driver.never(),
            goForward: Driver.never(),
            reload: Driver.never(),
            stopLoading: Driver.never(),
            bookmarkToggle: Driver.never(),
            menuTap: Driver.never()
        )

        let output = viewModel.transform(input: input)

        XCTAssertNotNil(output.title)
        XCTAssertNotNil(output.url)
        XCTAssertNotNil(output.canGoBack)
        XCTAssertNotNil(output.canGoForward)
        XCTAssertNotNil(output.isLoading)
        XCTAssertNotNil(output.estimatedProgress)
        XCTAssertNotNil(output.showMenu)
        XCTAssertNotNil(output.error)
    }

    // MARK: - WebView Configuration

    func testGetWebView_WhenCreated_AllowsBackForwardNavigationGestures() {
        let viewModel = WebBrowserViewModel()
        let webView = viewModel.getWebView()

        XCTAssertTrue(
            webView.allowsBackForwardNavigationGestures,
            "WebView should allow back/forward navigation gestures"
        )
    }
}
