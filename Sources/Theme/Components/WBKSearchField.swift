import UIKit
import SnapKit

public final class WBKSearchField: UIView {

    private let container = UIView()
    private let iconImageView = UIImageView()
    private let clearButton = UIButton(type: .custom)
    private(set) public var textField = UITextField()

    public var isEnabled: Bool = true {
        didSet {
            alpha = isEnabled ? 1.0 : ThemeTokens.Opacity.disabled
            isUserInteractionEnabled = isEnabled
            textField.isEnabled = isEnabled
        }
    }

    public var onTextChanged: ((String) -> Void)?
    public var onSearchButtonTapped: (() -> Void)?
    public var onCancelTapped: (() -> Void)?
    public var onBeginEditing: (() -> Void)?

    public var text: String? {
        get { textField.text }
        set {
            textField.text = newValue
            updateClearButtonVisibility()
        }
    }

    public var placeholder: String {
        get { textField.attributedPlaceholder?.string ?? "" }
        set {
            textField.attributedPlaceholder = NSAttributedString(
                string: newValue,
                attributes: [
                    .foregroundColor: ThemeTokens.Color.placeholder,
                    .font: ThemeTokens.Typography.body
                ]
            )
        }
    }

    public var leftIcon: UIImage? {
        get { iconImageView.image }
        set { iconImageView.image = newValue?.withRenderingMode(.alwaysTemplate) }
    }

    public var rightView: UIView? {
        didSet {
            if let view = rightView {
                textField.rightView = view
                textField.rightViewMode = .always
            } else {
                textField.rightView = clearButton
                textField.rightViewMode = .whileEditing
            }
        }
    }

    public init(placeholder: String = "搜索") {
        super.init(frame: .zero)
        accessibilityIdentifier = "wbk_search_field"
        setupUI()
        self.placeholder = placeholder
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @discardableResult
    public override func becomeFirstResponder() -> Bool {
        textField.becomeFirstResponder()
    }

    @discardableResult
    public override func resignFirstResponder() -> Bool {
        textField.resignFirstResponder()
    }

    private func setupUI() {
        addSubview(container)
        container.addSubview(iconImageView)
        container.addSubview(textField)

        container.backgroundColor = ThemeTokens.Color.backgroundSecondary
        container.layer.cornerRadius = ThemeTokens.ComponentContract.SearchField.cornerRadius
        container.layer.borderWidth = 0
        container.layer.borderColor = ThemeTokens.Color.primary.cgColor
        container.clipsToBounds = true

        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = ThemeTokens.Color.textTertiary
        iconImageView.image = LucideIcon.search.templateImage(pointSize: ThemeTokens.ComponentContract.SearchField.iconSize)

        clearButton.setImage(
            LucideIcon.xmark.templateImage(pointSize: ThemeTokens.ComponentContract.SearchField.iconSize),
            for: .normal
        )
        clearButton.tintColor = ThemeTokens.Color.textTertiary
        clearButton.addTarget(self, action: #selector(clearTapped), for: .touchUpInside)
        clearButton.snp.makeConstraints { make in
            make.width.height.equalTo(ThemeTokens.ComponentContract.TapTarget.minimumWidth)
        }

        textField.font = ThemeTokens.Typography.body
        textField.textColor = ThemeTokens.Color.text
        textField.returnKeyType = .search
        textField.clearButtonMode = .never
        textField.rightView = clearButton
        textField.rightViewMode = .whileEditing
        textField.delegate = self
        textField.addTarget(self, action: #selector(textDidChange), for: .editingChanged)

        container.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(ThemeTokens.ComponentContract.SearchField.height)
        }

        iconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(ThemeTokens.ComponentContract.SearchField.horizontalPadding)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(ThemeTokens.ComponentContract.SearchField.iconSize)
        }

        textField.snp.makeConstraints { make in
            make.leading.equalTo(iconImageView.snp.trailing).offset(ThemeTokens.Spacing.sm)
            make.trailing.equalToSuperview().offset(-ThemeTokens.ComponentContract.SearchField.horizontalPadding)
            make.top.bottom.equalToSuperview()
        }
    }

    @objc private func textDidChange() {
        onTextChanged?(textField.text ?? "")
        updateClearButtonVisibility()
    }

    @objc private func clearTapped() {
        textField.text = ""
        onTextChanged?("")
        onCancelTapped?()
        updateClearButtonVisibility()
    }

    private func updateClearButtonVisibility() {
        clearButton.isHidden = (textField.text ?? "").isEmpty
    }
}

extension WBKSearchField: UITextFieldDelegate {
    public func textFieldDidBeginEditing(_ textField: UITextField) {
        container.layer.borderWidth = 1
        container.layer.borderColor = ThemeTokens.Color.primary.cgColor
        iconImageView.tintColor = ThemeTokens.Color.primary
        onBeginEditing?()
    }

    public func textFieldDidEndEditing(_ textField: UITextField) {
        container.layer.borderWidth = 0
        iconImageView.tintColor = ThemeTokens.Color.textTertiary
    }

    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        onSearchButtonTapped?()
        textField.resignFirstResponder()
        return true
    }
}
