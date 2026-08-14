import UIKit
import WebBridgeKit
import SnapKit

/// Root view controller - a simple WebView container
/// This is the starting point for apps built with WebBridgeKit
class RootViewController: UIViewController {

    private let configuration: AppTemplateConfiguration
    private var didOpenInitialPWA = false

    init(configuration: AppTemplateConfiguration) {
        self.configuration = configuration
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        configuration = .safeDefaults
        super.init(coder: coder)
    }
    
    // MARK: - UI
    private lazy var urlTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Enter URL (e.g. https://example.com)"
        tf.borderStyle = .roundedRect
        tf.autocapitalizationType = .none
        tf.autocorrectionType = .no
        tf.keyboardType = .URL
        tf.returnKeyType = .go
        tf.delegate = self
        tf.text = configuration.initialPWAURL?.absoluteString
        tf.textColor = ThemeTokens.Color.text
        tf.backgroundColor = ThemeTokens.Color.surface
        return tf
    }()
    
    private lazy var goButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Go", for: .normal)
        btn.titleLabel?.font = ThemeTokens.Typography.buttonMedium
        btn.setTitleColor(ThemeTokens.Color.primary, for: .normal)
        btn.addTarget(self, action: #selector(openURL), for: .touchUpInside)
        return btn
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "WebBridgeKit App"
        view.backgroundColor = ThemeTokens.Color.background
        setupUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didOpenInitialPWA, configuration.initialPWAURL != nil else { return }
        didOpenInitialPWA = true
        openURL()
    }
}

// MARK: - UI Setup

private extension RootViewController {
    func setupUI() {
        let stack = UIStackView(arrangedSubviews: [urlTextField, goButton])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .fill
        
        urlTextField.snp.makeConstraints { make in
            make.height.equalTo(44)
        }
        
        goButton.snp.makeConstraints { make in
            make.width.equalTo(60)
        }
        
        view.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            make.left.right.equalToSuperview().inset(16)
        }
    }
}

// MARK: - Actions

private extension RootViewController {
    @objc func openURL() {
        guard let text = urlTextField.text, let url = URL(string: text) else {
            let alert = UIAlertController(title: "Invalid URL", message: "Please enter a valid URL", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        
        let params = WebBrowserParams.from(url: url)
        WebBrowserManager.shared.openBrowser(url: url, params: params, from: self)
    }
}

// MARK: - UITextFieldDelegate

extension RootViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        openURL()
        return true
    }
}
