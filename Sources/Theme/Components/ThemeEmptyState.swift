import UIKit
import SnapKit

public class ThemeEmptyState: UIView {
    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.tintColor = ThemeTokens.Color.textSecondary
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.title3
        label.textColor = ThemeTokens.Color.text
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    public let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.body
        label.textColor = ThemeTokens.Color.textSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        addSubview(iconImageView)
        addSubview(titleLabel)
        addSubview(descriptionLabel)

        iconImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview()
            make.width.height.equalTo(64)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconImageView.snp.bottom).offset(ThemeTokens.Spacing.md)
            make.leading.trailing.equalToSuperview()
        }

        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(ThemeTokens.Spacing.sm)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }
    }

    public func configure(icon: LucideIcon, title: String, description: String) {
        iconImageView.image = icon.templateImage(pointSize: 48, weight: .light)
        titleLabel.text = title
        descriptionLabel.text = description
    }

    public func configure(icon: String, title: String, description: String) {
        let config = UIImage.SymbolConfiguration(pointSize: 48, weight: .light)
        iconImageView.image = UIImage(systemName: icon, withConfiguration: config)?.withRenderingMode(.alwaysTemplate)
        titleLabel.text = title
        descriptionLabel.text = description
    }
}
