import UIKit
import WebBridgeKit
import SnapKit

class CommandShowcaseViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

    private let clipboardLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTypography.current.body
        label.textColor = ThemeColors.current.text
        label.numberOfLines = 0
        label.text = "(empty)"
        return label
    }()

    private let inputTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Enter command to decode (JSON/Base64/URL scheme)"
        tf.borderStyle = .roundedRect
        tf.font = ThemeTypography.current.body
        tf.autocapitalizationType = .none
        tf.autocorrectionType = .no
        return tf
    }()

    private let resultTextView: UITextView = {
        let tv = UITextView()
        tv.isEditable = false
        tv.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        tv.backgroundColor = ThemeColors.current.surface
        tv.layer.cornerRadius = ThemeCornerRadius.default.md
        tv.text = "Parse result will appear here..."
        return tv
    }()

    private let routeLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTypography.current.body
        label.textColor = ThemeColors.current.text
        label.numberOfLines = 0
        label.text = "Route: (none)"
        return label
    }()

    private let isCommandLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTypography.current.caption1
        label.textColor = ThemeColors.current.textSecondary
        label.text = ""
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "口令"
        view.backgroundColor = ThemeColors.current.background
        setupUI()
        readClipboard()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        readClipboard()
    }

    private func setupUI() {
        stackView.axis = .vertical
        stackView.spacing = ThemeSpacing.default.md
        stackView.alignment = .fill

        let clipboardHeader = makeHeader("Clipboard Content")
        stackView.addArrangedSubview(clipboardHeader)
        stackView.addArrangedSubview(clipboardLabel)

        let isCommandStack = UIStackView()
        isCommandStack.axis = .horizontal
        isCommandStack.spacing = ThemeTokens.Spacing.sm
        let looksLikeLabel = UILabel()
        looksLikeLabel.font = ThemeTypography.current.caption1
        looksLikeLabel.textColor = ThemeColors.current.textSecondary
        looksLikeLabel.text = "Looks like command:"
        isCommandStack.addArrangedSubview(looksLikeLabel)
        isCommandStack.addArrangedSubview(isCommandLabel)
        stackView.addArrangedSubview(isCommandStack)

        let parseClipboardButton = makeButton("Parse Clipboard", style: .primary) { [weak self] in
            self?.parseClipboard()
        }
        stackView.addArrangedSubview(parseClipboardButton)

        let divider1 = makeDivider()
        stackView.addArrangedSubview(divider1)

        let decodeHeader = makeHeader("Manual Decode")
        stackView.addArrangedSubview(decodeHeader)
        inputTextField.heightAnchor.constraint(equalToConstant: 44).isActive = true
        stackView.addArrangedSubview(inputTextField)

        let decodeButton = makeButton("Decode Input", style: .primary) { [weak self] in
            self?.decodeInput()
        }
        stackView.addArrangedSubview(decodeButton)

        let testJSON = makeButton("Load Test JSON", style: .secondary) { [weak self] in
            self?.loadTestJSON()
        }
        stackView.addArrangedSubview(testJSON)

        let resultHeader = makeHeader("Parse Result")
        stackView.addArrangedSubview(resultHeader)
        resultTextView.heightAnchor.constraint(equalToConstant: 200).isActive = true
        stackView.addArrangedSubview(resultTextView)

        let routeHeader = makeHeader("Route")
        stackView.addArrangedSubview(routeHeader)
        stackView.addArrangedSubview(routeLabel)

        let testRouteButton = makeButton("Test CommandRouter", style: .secondary) { [weak self] in
            self?.testRouter()
        }
        stackView.addArrangedSubview(testRouteButton)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(stackView)

        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }

        stackView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(ThemeSpacing.default.md)
            make.left.right.equalToSuperview().inset(ThemeSpacing.default.md)
            make.bottom.equalToSuperview().offset(-ThemeSpacing.default.lg)
            make.width.equalTo(scrollView).offset(-ThemeSpacing.default.md * 2)
        }
    }

    private func readClipboard() {
        if let text = ClipboardMonitor.shared.readClipboard() {
            clipboardLabel.text = text
            let isCommand = ClipboardMonitor.shared.looksLikeCommand(text)
            isCommandLabel.text = isCommand ? "Yes" : "No"
            isCommandLabel.textColor = isCommand ? ThemeColors.current.success : ThemeColors.current.textSecondary
        } else {
            clipboardLabel.text = "(clipboard is empty)"
            isCommandLabel.text = "N/A"
        }
    }

    private func parseClipboard() {
        Task { @MainActor in
            do {
                guard let payload = try await CommandParser.shared.parseFromClipboard() else {
                    resultTextView.text = "No valid command found in clipboard"
                    return
                }
                displayPayload(payload)
            } catch {
                resultTextView.text = "Parse error: \(error.localizedDescription)"
            }
        }
    }

    private func decodeInput() {
        guard let text = inputTextField.text, !text.isEmpty else {
            resultTextView.text = "Please enter a command string"
            return
        }
        Task { @MainActor in
            do {
                let payload = try await CommandParser.shared.parse(text)
                displayPayload(payload)
            } catch {
                resultTextView.text = "Decode error: \(error.localizedDescription)"
            }
        }
    }

    private func loadTestJSON() {
        let testPayload: [String: Any] = [
            "appid": "com.example.testapp",
            "url": "https://wbk.shanbox.19930810.xyz:8443/test_resources/bridge-hub.html",
            "title": "Test Page",
            "icon": "https://wbk.shanbox.19930810.xyz:8443/favicon.ico",
            "token": "test-token-123",
            "ts": Date().timeIntervalSince1970,
            "nonce": UUID().uuidString
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: testPayload) else { return }
        inputTextField.text = data.base64EncodedString()
    }

    private func displayPayload(_ payload: CommandPayload) {
        let lines = [
            "appid: \(payload.appid)",
            "url: \(payload.url ?? "(nil)")",
            "title: \(payload.title ?? "(nil)")",
            "icon: \(payload.icon ?? "(nil)")",
            "token: \(payload.hasToken ? "***" : "(nil)")",
            "extra: \(payload.extra ?? [:])",
            "timestamp: \(payload.timestamp.map { String($0) } ?? "(nil)")",
            "nonce: \(payload.nonce ?? "(nil)")"
        ]
        resultTextView.text = lines.joined(separator: "\n")
    }

    private func testRouter() {
        let payload = CommandPayload(
            appid: "com.test.app",
            url: "https://wbk.shanbox.19930810.xyz:8443",
            title: "Test"
        )
        let route = CommandRouter.shared.route(payload)
        switch route {
        case .cachedApp(let appid):
            routeLabel.text = "Route: cachedApp(\(appid))"
        case .url(let url):
            routeLabel.text = "Route: url(\(url))"
        case .deeplink(let url):
            routeLabel.text = "Route: deeplink(\(url))"
        case .none:
            routeLabel.text = "Route: none"
        }
    }

    private func makeHeader(_ title: String) -> UIView {
        let header = ThemeSectionHeader()
        header.configure(title: title)
        return header
    }

    private func makeButton(_ title: String, style: ThemeButtonStyle, action: @escaping () -> Void) -> ThemeButton {
        let button = ThemeButton()
        button.configure(title: title, style: style)
        button.snp.makeConstraints { make in
            make.height.equalTo(44)
        }
        return button
    }

    private func makeDivider() -> UIView {
        let view = UIView()
        view.backgroundColor = ThemeColors.current.divider
        view.snp.makeConstraints { make in
            make.height.equalTo(1)
        }
        return view
    }
}
