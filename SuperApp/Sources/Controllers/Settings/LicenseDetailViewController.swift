import UIKit
import WebBridgeKit

class LicenseDetailViewController: UIViewController {

    private let entry: LicenseEntry

    private lazy var textView: UITextView = {
        let tv = UITextView()
        tv.isEditable = false
        tv.isSelectable = true
        tv.backgroundColor = ThemeTokens.Color.background
        tv.font = ThemeTokens.Typography.footnote
        tv.textColor = ThemeTokens.Color.text
        tv.accessibilityIdentifier = "licenseDetail.textView"
        tv.textContainerInset = UIEdgeInsets(
            top: ThemeTokens.Spacing.md,
            left: ThemeTokens.Spacing.md,
            bottom: ThemeTokens.Spacing.md,
            right: ThemeTokens.Spacing.md
        )
        tv.textContainer.lineFragmentPadding = 0
        return tv
    }()

    init(entry: LicenseEntry) {
        self.entry = entry
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = entry.name
        view.backgroundColor = ThemeTokens.Color.background
        view.accessibilityIdentifier = "licenseDetail.root"

        view.addSubview(textView)
        textView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }

        textView.text = entry.fullLicenseText
    }
}
