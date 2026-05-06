import UIKit
import SnapKit

public class ThemeSectionHeader: UIView {
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTypography.current.title2
        label.textColor = ThemeColors.current.text
        return label
    }()

    private let actionButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = ThemeTypography.current.caption1
        button.setTitleColor(ThemeColors.current.primary, for: .normal)
        button.isHidden = true
        return button
    }()

    public var onAction: (() -> Void)?

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        addSubview(titleLabel)
        addSubview(actionButton)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
        }

        actionButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
        }

        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)
    }

    public func configure(title: String, actionTitle: String? = nil) {
        titleLabel.text = title
        if let actionTitle = actionTitle {
            actionButton.setTitle(actionTitle, for: .normal)
            actionButton.isHidden = false
        } else {
            actionButton.isHidden = true
        }
    }

    @objc private func actionTapped() {
        onAction?()
    }
}
