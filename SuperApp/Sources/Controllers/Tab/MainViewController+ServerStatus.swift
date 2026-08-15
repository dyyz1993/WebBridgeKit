import UIKit
import SnapKit
import WebBridgeKit

final class ServerStatusBlock: UIView {

    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeTokens.Color.cardBackground
        view.layer.cornerRadius = ThemeTokens.CornerRadius.card
        let shadow = ThemeTokens.Shadows.card
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: shadow.offsetX, height: shadow.offsetY)
        view.layer.shadowRadius = shadow.radius
        view.layer.shadowOpacity = Float(shadow.opacity)
        return view
    }()

    private let serverIcon: UIImageView = {
        let iv = UIImageView()
        iv.image = LucideIcon.server.templateImage(pointSize: ThemeTokens.Icons.Sizes.sm, weight: .medium)
        iv.tintColor = ThemeTokens.Color.textSecondary
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let urlLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.metadata
        label.textColor = ThemeTokens.Color.textSecondary
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingMiddle
        return label
    }()

    private let statusBadge = WBKStatusBadge(text: "", style: .default)

    private let tokenPill: UIView = {
        let v = UIView()
        v.backgroundColor = ThemeTokens.Color.primarySoft
        v.layer.cornerRadius = ThemeTokens.CornerRadius.sm
        v.clipsToBounds = true
        return v
    }()

    private let keyIcon: UIImageView = {
        let iv = UIImageView()
        iv.image = LucideIcon.key.templateImage(pointSize: ThemeTokens.Icons.Sizes.xs, weight: .medium)
        iv.tintColor = ThemeTokens.Color.primary
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let tokenLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.monospaceMeta
        label.textColor = ThemeTokens.Color.primary
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingMiddle
        label.accessibilityIdentifier = "home.token_card.token_label"
        return label
    }()

    private let copyButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(L10n.tr("home.token_card.copy_token"), for: .normal)
        button.titleLabel?.font = ThemeTokens.Typography.metadata
        button.setTitleColor(ThemeTokens.Color.primary, for: .normal)
        button.backgroundColor = ThemeTokens.Color.primarySoft
        button.layer.cornerRadius = ThemeTokens.CornerRadius.card
        button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 16, bottom: 6, right: 16)
        button.accessibilityIdentifier = "home.token_card.copy_button"
        return button
    }()

    private let registerButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(L10n.tr("home.token_card.register"), for: .normal)
        button.titleLabel?.font = ThemeTokens.Typography.metadata
        button.setTitleColor(ThemeTokens.Color.surface, for: .normal)
        button.backgroundColor = ThemeTokens.Color.primary
        button.layer.cornerRadius = ThemeTokens.CornerRadius.sm
        button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 16, bottom: 6, right: 16)
        button.isHidden = true
        button.accessibilityIdentifier = "home.token_card.register_button"
        return button
    }()

    private var onCopy: (() -> Void)?
    private var onRegister: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        addSubview(containerView)
        containerView.addSubview(serverIcon)
        containerView.addSubview(urlLabel)
        containerView.addSubview(statusBadge)
        containerView.addSubview(tokenPill)
        tokenPill.addSubview(keyIcon)
        tokenPill.addSubview(tokenLabel)
        containerView.addSubview(copyButton)
        containerView.addSubview(registerButton)

        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        serverIcon.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(ThemeTokens.Spacing.md)
            make.left.equalToSuperview().offset(ThemeTokens.Spacing.lg)
            make.width.height.equalTo(ThemeTokens.Icons.Sizes.sm)
        }

        urlLabel.snp.makeConstraints { make in
            make.centerY.equalTo(serverIcon)
            make.left.equalTo(serverIcon.snp.right).offset(ThemeTokens.Spacing.sm)
            make.right.lessThanOrEqualTo(statusBadge.snp.left).offset(-ThemeTokens.Spacing.sm)
        }

        statusBadge.snp.makeConstraints { make in
            make.centerY.equalTo(serverIcon)
            make.right.equalToSuperview().offset(-ThemeTokens.Spacing.lg)
        }

        tokenPill.snp.makeConstraints { make in
            make.top.equalTo(serverIcon.snp.bottom).offset(ThemeTokens.Spacing.sm)
            make.left.equalToSuperview().offset(ThemeTokens.Spacing.lg)
            make.right.equalTo(copyButton.snp.left).offset(-ThemeTokens.Spacing.md)
            make.height.equalTo(28)
        }

        keyIcon.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalToSuperview().offset(ThemeTokens.Spacing.sm)
            make.width.height.equalTo(ThemeTokens.Icons.Sizes.xs)
        }

        tokenLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalTo(keyIcon.snp.right).offset(ThemeTokens.Spacing.xs)
            make.right.equalToSuperview().offset(-ThemeTokens.Spacing.sm)
        }

        copyButton.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-ThemeTokens.Spacing.lg)
            make.centerY.equalTo(tokenPill)
            make.height.equalTo(28)
        }

        registerButton.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-ThemeTokens.Spacing.lg)
            make.centerY.equalTo(tokenPill)
        }

        copyButton.addTarget(self, action: #selector(copyTapped), for: .touchUpInside)
        registerButton.addTarget(self, action: #selector(registerTapped), for: .touchUpInside)
    }

    func configure(serverURL: String, deviceToken: String, isRegistered: Bool, onCopy: @escaping () -> Void, onRegister: @escaping () -> Void) {
        self.onCopy = onCopy
        self.onRegister = onRegister
        urlLabel.text = serverURL

        if isRegistered {
            if deviceToken.count > 8 {
                let prefix = deviceToken.prefix(4)
                let suffix = deviceToken.suffix(4)
                tokenLabel.text = "\(prefix)****\(suffix)"
            } else {
                tokenLabel.text = deviceToken
            }
            tokenLabel.textColor = ThemeTokens.Color.primary
            copyButton.isHidden = false
            registerButton.isHidden = true
            statusBadge.text = L10n.tr("home.status.connected")
            statusBadge.style = .success
        } else {
            tokenLabel.text = L10n.tr("home.token_card.not_registered")
            tokenLabel.textColor = ThemeTokens.Color.textSecondary
            copyButton.isHidden = true
            registerButton.isHidden = false
            statusBadge.text = L10n.tr("home.status.unregistered")
            statusBadge.style = .warning
        }
    }

    @objc private func copyTapped() { onCopy?() }
    @objc private func registerTapped() { onRegister?() }
}
