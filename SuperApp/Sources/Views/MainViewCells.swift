import UIKit
import SnapKit
import WebBridgeKit

class PushTokenCardCell: UICollectionViewCell {
    static let identifier = "PushTokenCardCell"

    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeColors.current.cardBackground
        view.layer.cornerRadius = 16
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 8
        view.layer.shadowOpacity = 0.06
        return view
    }()

    private let serverIcon: UIImageView = {
        let iv = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        iv.image = LucideIcon.server.image(pointSize: 14, weight: .medium)
        iv.tintColor = ThemeTokens.Colors.Light.textTertiary
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let urlLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        label.textColor = ThemeTokens.Colors.Light.textTertiary
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingMiddle
        return label
    }()

    private let keyIcon: UIImageView = {
        let iv = UIImageView()
        iv.image = LucideIcon.key.image(pointSize: 14, weight: .medium)
        iv.tintColor = ThemeTokens.Colors.Light.textTertiary
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let tokenLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .medium)
        label.textColor = ThemeColors.current.primary
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingMiddle
        return label
    }()

    private let copyButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(L10n.tr("common.copy"), for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        button.setTitleColor(ThemeColors.current.primary, for: .normal)
        return button
    }()

    private let registerButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(L10n.tr("home.token_card.register"), for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = ThemeColors.current.primary
        button.layer.cornerRadius = 6
        button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 16, bottom: 6, right: 16)
        button.isHidden = true
        return button
    }()

    var onCopyTapped: (() -> Void)?
    var onRegisterTapped: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onCopyTapped = nil
        onRegisterTapped = nil
    }

    private func setupUI() {
        contentView.addSubview(containerView)
        containerView.addSubview(serverIcon)
        containerView.addSubview(urlLabel)
        containerView.addSubview(keyIcon)
        containerView.addSubview(tokenLabel)
        containerView.addSubview(copyButton)
        containerView.addSubview(registerButton)

        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        serverIcon.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.left.equalToSuperview().offset(16)
            make.width.height.equalTo(16)
        }

        urlLabel.snp.makeConstraints { make in
            make.centerY.equalTo(serverIcon)
            make.left.equalTo(serverIcon.snp.right).offset(8)
            make.right.equalToSuperview().offset(-16)
        }

        keyIcon.snp.makeConstraints { make in
            make.top.equalTo(serverIcon.snp.bottom).offset(14)
            make.left.equalToSuperview().offset(16)
            make.width.height.equalTo(16)
        }

        tokenLabel.snp.makeConstraints { make in
            make.centerY.equalTo(keyIcon)
            make.left.equalTo(keyIcon.snp.right).offset(8)
            make.right.equalTo(copyButton.snp.left).offset(-12)
        }

        copyButton.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-16)
            make.centerY.equalTo(keyIcon)
        }

        registerButton.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-16)
            make.centerY.equalTo(keyIcon)
        }

        copyButton.addTarget(self, action: #selector(copyTapped), for: .touchUpInside)
        registerButton.addTarget(self, action: #selector(registerTapped), for: .touchUpInside)
    }

    func configure(serverURL: String, deviceToken: String, isRegistered: Bool) {
        if isRegistered {
            urlLabel.text = serverURL
            if deviceToken.count > 8 {
                let prefix = deviceToken.prefix(4)
                let suffix = deviceToken.suffix(4)
                tokenLabel.text = "\(prefix)****\(suffix)"
            } else {
                tokenLabel.text = deviceToken
            }
            tokenLabel.textColor = ThemeColors.current.primary
            copyButton.isHidden = false
            registerButton.isHidden = true
        } else {
            urlLabel.text = serverURL
            tokenLabel.text = L10n.tr("home.token_card.not_registered")
            tokenLabel.textColor = ThemeTokens.Colors.Light.textTertiary
            copyButton.isHidden = true
            registerButton.isHidden = false
        }
    }

    @objc private func copyTapped() {
        onCopyTapped?()
    }

    @objc private func registerTapped() {
        onRegisterTapped?()
    }
}

class QuickActionCell: UICollectionViewCell {
    static let identifier = "QuickActionCell"

    private let stackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.distribution = .fillEqually
        sv.spacing = 0
        return sv
    }()

    var onActionTapped: ((Int) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onActionTapped = nil
    }

    private func setupUI() {
        contentView.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func configure(actions: [(icon: String, title: String, color: UIColor)]) {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, action) in actions.enumerated() {
            let btn = createActionButton(icon: action.icon, title: action.title, color: action.color)
            btn.tag = index
            btn.addTarget(self, action: #selector(actionTapped(_:)), for: .touchUpInside)
            stackView.addArrangedSubview(btn)
        }
    }

    private func createActionButton(icon: String, title: String, color: UIColor) -> UIButton {
        let button = UIButton(type: .system)
        button.backgroundColor = .clear

        let circleView: UIView = {
            let v = UIView()
            v.backgroundColor = color.withAlphaComponent(0.12)
            v.layer.cornerRadius = 24
            return v
        }()

        let iconView = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        iconView.image = UIImage(systemName: icon, withConfiguration: config)
        iconView.tintColor = .white
        iconView.contentMode = .scaleAspectFit

        let circleBg = UIView()
        circleBg.backgroundColor = color
        circleBg.layer.cornerRadius = 24
        circleBg.clipsToBounds = true
        circleBg.addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(20)
        }

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        titleLabel.textColor = ThemeTokens.Colors.Light.textSecondary
        titleLabel.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [circleBg, titleLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 6
        stack.isUserInteractionEnabled = false

        button.addSubview(stack)

        stack.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        circleBg.snp.makeConstraints { make in
            make.width.height.equalTo(48)
        }

        return button
    }

    @objc private func actionTapped(_ sender: UIButton) {
        onActionTapped?(sender.tag)
    }
}

class SectionHeaderView: UICollectionReusableView {
    static let identifier = "SectionHeader"

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        label.textColor = ThemeTokens.Colors.Light.textTertiary
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.trailing.lessThanOrEqualToSuperview().offset(-16)
            make.centerY.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class CommandBannerView: UIView {

    var onTap: (() -> Void)?
    var onDismiss: (() -> Void)?

    private let iconView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.tintColor = ThemeColors.current.primary
        iv.image = LucideIcon.shield.image(pointSize: 15, weight: .semibold)
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = ThemeColors.current.primary
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private let dismissButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(LucideIcon.xmark.image(pointSize: 14, weight: .bold), for: .normal)
        button.tintColor = ThemeTokens.Colors.Light.textTertiary
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = ThemeColors.current.primary.withAlphaComponent(0.08)
        layer.cornerRadius = ThemeTokens.CornerRadius.md
        clipsToBounds = true

        addSubview(iconView)
        addSubview(titleLabel)
        addSubview(dismissButton)

        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(18)
        }

        dismissButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-12)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(32)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(8)
            make.trailing.equalTo(dismissButton.snp.leading).offset(-4)
            make.centerY.equalToSuperview()
        }

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(bannerTapped))
        addGestureRecognizer(tapGesture)

        dismissButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
    }

    func configure(title: String) {
        titleLabel.text = L10n.tr("home.command.banner_format", title)
    }

    @objc private func bannerTapped() {
        onTap?()
    }

    @objc private func dismissTapped() {
        onDismiss?()
    }
}
