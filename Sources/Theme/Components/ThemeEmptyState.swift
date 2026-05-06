import UIKit
import SnapKit

public class ThemeEmptyState: UIView {
    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.tintColor = ThemeColors.current.textSecondary
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTypography.current.title2
        label.textColor = ThemeColors.current.text
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTypography.current.body
        label.textColor = ThemeColors.current.textSecondary
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
            make.top.equalTo(iconImageView.snp.bottom).offset(ThemeSpacing.default.md)
            make.leading.trailing.equalToSuperview()
        }

        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(ThemeSpacing.default.sm)
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
