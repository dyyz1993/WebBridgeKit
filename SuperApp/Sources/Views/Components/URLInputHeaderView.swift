//
//  URLInputHeaderView.swift
//  SuperApp
//
//  Collection reusable header view with auto URL type detection.
//

import UIKit
import SnapKit
import WebBridgeKit

class URLInputHeaderView: UICollectionReusableView {

    static let elementKind = UICollectionView.elementKindSectionHeader
    static let identifier = "URLInputHeaderView"

    var onSubmit: ((String) -> Void)?
    var onTextChanged: ((String, URLType) -> Void)?

    private let containerStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.spacing = 10
        sv.alignment = .center
        sv.isLayoutMarginsRelativeArrangement = true
        sv.layoutMargins = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        return sv
    }()

    private let textField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "输入 URL 以添加或检测..."
        tf.font = ThemeTokens.Typography.body
        tf.textColor = ThemeTokens.Color.text
        tf.keyboardType = .URL
        tf.autocapitalizationType = .none
        tf.autocorrectionType = .no
        tf.clearButtonMode = .whileEditing
        tf.leftViewMode = .always
        tf.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 8, height: 0))
        tf.layer.borderColor = ThemeTokens.Color.border.cgColor
        tf.layer.borderWidth = 1
        tf.layer.cornerRadius = ThemeTokens.CornerRadius.md
        tf.clipsToBounds = true
        return tf
    }()

    private let typeIndicator: UIView = {
        let v = UIView()
        v.layer.cornerRadius = ThemeTokens.CornerRadius.sm
        v.clipsToBounds = true
        return v
    }()

    private let typeLabel: UILabel = {
        let l = UILabel()
        l.font = ThemeTokens.Typography.caption2
        l.textColor = .white
        l.textAlignment = .center
        l.numberOfLines = 1
        return l
    }()

    private let submitButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setImage(LucideIcon.plus.image(pointSize: 18), for: .normal)
        btn.tintColor = ThemeTokens.Color.primary
        btn.setTitle("添加", for: .normal)
        btn.titleLabel?.font = ThemeTokens.Typography.subheadline
        btn.setTitleColor(ThemeTokens.Color.primary, for: .normal)
        btn.contentEdgeInsets = UIEdgeInsets(top: 6, left: 8, bottom: 6, right: 8)
        return btn
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        typeIndicator.addSubview(typeLabel)
        for v in [textField, typeIndicator, submitButton] { containerStack.addArrangedSubview(v) }
        addSubview(containerStack)

        containerStack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        typeIndicator.snp.makeConstraints { make in
            make.width.greaterThanOrEqualTo(60)
            make.height.equalTo(26)
        }

        submitButton.snp.makeConstraints { make in
            make.height.equalTo(34)
        }

        textField.addTarget(self, action: #selector(textFieldChanged), for: .editingChanged)
        submitButton.addTarget(self, action: #selector(submitTapped), for: .touchUpInside)

        updateTypeIndicator(.other)
        backgroundColor = ThemeTokens.Color.background
    }

    @objc private func textFieldChanged() {
        guard let text = textField.text, !text.isEmpty else {
            updateTypeIndicator(.other)
            return
        }
        let type = URLType.detect(from: text)
        updateTypeIndicator(type)
        onTextChanged?(text, type)
    }

    @objc private func submitTapped() {
        guard let text = textField.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        onSubmit?(text.trimmingCharacters(in: .whitespacesAndNewlines))
        textField.text = nil
        updateTypeIndicator(.other)
    }

    func setText(_ text: String) {
        textField.text = text
        textFieldChanged()
    }

    override func becomeFirstResponder() -> Bool {
        return textField.becomeFirstResponder()
    }

    private func updateTypeIndicator(_ type: URLType) {
        typeLabel.text = type.displayName
        typeIndicator.backgroundColor = indicatorColor(for: type)
    }

    private func indicatorColor(for type: URLType) -> UIColor {
        switch type {
        case .htmlPage: return ThemeTokens.Color.primary
        case .webApp: return ThemeTokens.Color.info
        case .apiEndpoint: return ThemeTokens.Color.success
        case .staticResource: return ThemeTokens.Color.warning
        case .websocket: return ThemeTokens.Color.gradientEnd
        case .mcpServer: return ThemeTokens.Color.error
        case .manifest: return ThemeTokens.Color.info
        case .other: return ThemeTokens.Color.textTertiary
        }
    }
}
