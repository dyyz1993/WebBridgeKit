import UIKit
import WebBridgeKit

/// One place to inspect and manage the two independent Drel push channels.
/// Selecting a channel changes the address copied on Home; it never removes
/// the other channel's registration or historical messages.
final class DrelPushChannelConfigurationViewController: UIViewController {
    private let stack = UIStackView()
    private let currentChannelLabel = UILabel()
    private let officialDetailLabel = UILabel()
    private let selfHostedDetailLabel = UILabel()
    private let useOfficialButton = UIButton(type: .system)
    private let useSelfHostedButton = UIButton(type: .system)
    private let copyAddressButton = UIButton(type: .system)
    private let copyKeyButton = UIButton(type: .system)
    private let rotateOfficialButton = UIButton(type: .system)
    private let manageSelfHostedButton = UIButton(type: .system)

    private let officialBaseURL = HTMLAppGatewayDefaults.official.baseURL
    private var officialIdentity: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "推送通道"
        view.backgroundColor = ThemeTokens.Color.background
        setupUI()
        refresh()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
    }

    // MARK: - UI construction

    private func setupUI() {
        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        stack.axis = .vertical
        stack.spacing = 16
        scrollView.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -28)
        ])

        // Intro lives in its own padded card so explanatory copy reads as
        // content, not as loose text floating on the page background.
        stack.addArrangedSubview(
            paddedCard(
                [makeLabel(
                    "选择的通道仅决定首页复制和示例发送使用哪个地址。官方与自定义通道会各自保持登记；切换不会删除另一条通道，也不会清空消息记录。",
                    style: .subheadline,
                    color: ThemeTokens.Color.textSecondary
                )],
                backgroundColor: ThemeTokens.Color.cardBackground
            )
        )

        // The active-channel highlight is a padded tinted card. The label is
        // inset by real constraints — UILabel does not consume its own
        // layoutMargins, so text previously rendered flush against the
        // rounded corners (S2).
        currentChannelLabel.numberOfLines = 0
        currentChannelLabel.font = ThemeTokens.Typography.body
        currentChannelLabel.textColor = ThemeTokens.Color.text
        stack.addArrangedSubview(
            paddedCard(
                [currentChannelLabel],
                backgroundColor: ThemeTokens.Color.primary.withAlphaComponent(0.1),
                spacing: 8
            )
        )

        stack.addArrangedSubview(sectionTitle("官方 Drel"))
        configureDetailLabel(officialDetailLabel)
        useOfficialButton.addTarget(self, action: #selector(selectOfficial), for: .touchUpInside)
        let officialActions = UIStackView(arrangedSubviews: [copyAddressButton, copyKeyButton])
        officialActions.axis = .horizontal
        officialActions.spacing = 12
        officialActions.distribution = .fillEqually
        copyAddressButton.addTarget(self, action: #selector(copyCurrentAddress), for: .touchUpInside)
        copyKeyButton.addTarget(self, action: #selector(copyCurrentKey), for: .touchUpInside)
        rotateOfficialButton.setTitle("重新生成官方地址", for: .normal)
        rotateOfficialButton.setTitleColor(ThemeTokens.Color.error, for: .normal)
        rotateOfficialButton.addTarget(self, action: #selector(confirmOfficialRotation), for: .touchUpInside)
        stack.addArrangedSubview(
            paddedCard(
                [officialDetailLabel, useOfficialButton, officialActions, rotateOfficialButton],
                backgroundColor: ThemeTokens.Color.cardBackground
            )
        )

        stack.addArrangedSubview(sectionTitle("自定义推送"))
        configureDetailLabel(selfHostedDetailLabel)
        useSelfHostedButton.addTarget(self, action: #selector(selectSelfHosted), for: .touchUpInside)
        manageSelfHostedButton.setTitle("添加或管理自定义通道", for: .normal)
        manageSelfHostedButton.addTarget(self, action: #selector(openSelfHostedManagement), for: .touchUpInside)
        stack.addArrangedSubview(
            paddedCard(
                [selfHostedDetailLabel, useSelfHostedButton, manageSelfHostedButton],
                backgroundColor: ThemeTokens.Color.cardBackground
            )
        )

        stack.addArrangedSubview(
            makeLabel(
                "说明：这里的“推送标识 / deviceKey”是公开的能力地址组成部分，不是登录密码。持有者可以向这台设备发消息；如泄露，请在对应通道重新生成地址。加密私钥不会显示、复制或上传。",
                style: .footnote,
                color: ThemeTokens.Color.textSecondary
            )
        )

        [useOfficialButton, useSelfHostedButton, copyAddressButton, copyKeyButton,
         rotateOfficialButton, manageSelfHostedButton].forEach(configureButton)
        // Three visual tiers: primary switch action, secondary copies/entry
        // points, destructive rotation stays a plain red text button.
        useOfficialButton.backgroundColor = ThemeTokens.Color.primary.withAlphaComponent(0.1)
        useOfficialButton.setTitleColor(ThemeTokens.Color.primary, for: .normal)
        useSelfHostedButton.backgroundColor = ThemeTokens.Color.primary.withAlphaComponent(0.1)
        useSelfHostedButton.setTitleColor(ThemeTokens.Color.primary, for: .normal)
        [copyAddressButton, copyKeyButton, manageSelfHostedButton].forEach {
            $0.backgroundColor = ThemeTokens.Color.background
            $0.setTitleColor(ThemeTokens.Color.text, for: .normal)
        }
        rotateOfficialButton.backgroundColor = .clear
        copyAddressButton.accessibilityIdentifier = "pushChannels.copyAddress"
        copyKeyButton.accessibilityIdentifier = "pushChannels.copyKey"
        useOfficialButton.accessibilityIdentifier = "pushChannels.useOfficial"
        useSelfHostedButton.accessibilityIdentifier = "pushChannels.useSelfHosted"
        manageSelfHostedButton.accessibilityIdentifier = "pushChannels.manageSelfHosted"
    }

    /// Card container with real edge insets; every text block on this page is
    /// hosted in one so no label ever touches a rounded corner.
    private func paddedCard(_ views: [UIView], backgroundColor: UIColor, spacing: CGFloat = 12) -> UIView {
        let card = UIView()
        card.backgroundColor = backgroundColor
        card.layer.cornerRadius = ThemeTokens.CornerRadius.lg
        card.clipsToBounds = true
        let inner = UIStackView(arrangedSubviews: views)
        inner.axis = .vertical
        inner.spacing = spacing
        inner.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            inner.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            inner.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            inner.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14)
        ])
        return card
    }

    // MARK: - State

    private func refresh() {
        officialIdentity = try? OfficialPushIdentityStore.shared.currentOrMigrateToShortIdentity()
        let officialURL = officialAddress
        let channels = DrelPushChannelStore.shared.channels(officialPushURL: officialURL)
        let active = DrelPushChannelStore.shared.activeChannel(officialPushURL: officialURL)
        let selfHosted = SelfHostedPushConfiguration.load()

        currentChannelLabel.text = "当前用于复制与示例发送：\(active.name)\n\(active.isOfficial ? "官方默认通道" : "自定义直连通道")"
        officialDetailLabel.text = "默认可用，无需填写服务器。\n服务地址：\(officialBaseURL)\n推送标识：\(masked(officialIdentity))\n用途：为你的脚本、网页或 Agent 提供 Drel 官方推送入口。"

        if let selfHosted {
            selfHostedDetailLabel.text = selfHostedText(for: selfHosted)
            useSelfHostedButton.isEnabled = true
            useSelfHostedButton.alpha = 1
            useSelfHostedButton.setTitle(active.isOfficial ? "设为当前复制通道" : "当前正在使用", for: .normal)
        } else {
            selfHostedDetailLabel.text = "尚未添加。可扫描你部署服务提供的二维码，或粘贴兼容的 HTTPS 服务地址。\n用途：让你用自己选定的直连服务发送消息；它与官方通道并存。"
            useSelfHostedButton.isEnabled = false
            useSelfHostedButton.alpha = 0.45
            useSelfHostedButton.setTitle("添加后可切换", for: .normal)
        }

        useOfficialButton.setTitle(active.isOfficial ? "当前正在使用" : "设为当前复制通道", for: .normal)
        copyAddressButton.setTitle("复制当前完整地址", for: .normal)
        copyKeyButton.setTitle("复制当前推送标识", for: .normal)
        rotateOfficialButton.isHidden = !active.isOfficial

        // The active channel must exist in the persisted channel list. A
        // removed custom configuration safely falls back to the official row.
        if !channels.contains(where: { $0.id == active.id }) {
            DrelPushChannelStore.shared.select(channels[0])
        }
    }

    private var officialAddress: String {
        guard let officialIdentity, !officialIdentity.isEmpty else { return "" }
        return "\(officialBaseURL)/\(officialIdentity)"
    }

    // MARK: - Actions

    @objc private func selectOfficial() {
        let official = DrelPushChannelStore.shared
            .channels(officialPushURL: officialAddress)
            .first { $0.isOfficial }
        guard let official else { return }
        DrelPushChannelStore.shared.select(official)
        refresh()
    }

    @objc private func selectSelfHosted() {
        let channels = DrelPushChannelStore.shared.channels(officialPushURL: officialAddress)
        guard let selfHosted = channels.first(where: { !$0.isOfficial }) else { return }
        DrelPushChannelStore.shared.select(selfHosted)
        refresh()
    }

    @objc private func copyCurrentAddress() {
        let channel = DrelPushChannelStore.shared.activeChannel(officialPushURL: officialAddress)
        UIPasteboard.general.string = channel.pushURL
        showFeedback("已复制 \(channel.name) 的完整地址")
    }

    @objc private func copyCurrentKey() {
        let channel = DrelPushChannelStore.shared.activeChannel(officialPushURL: officialAddress)
        let key = channel.pushURL.split(separator: "/").last.map(String.init) ?? ""
        guard !key.isEmpty else { return }
        UIPasteboard.general.string = key
        showFeedback("已复制推送标识")
    }

    @objc private func openSelfHostedManagement() {
        navigationController?.pushViewController(SelfHostedPushConfigurationViewController(), animated: true)
    }

    @objc private func confirmOfficialRotation() {
        let alert = UIAlertController(
            title: "重新生成官方地址？",
            message: "旧官方地址会停止向这台设备推送。请同步更新脚本、网页和 Agent 中保存的地址。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "重新生成", style: .destructive) { [weak self] _ in
            self?.rotateOfficialAddress()
        })
        present(alert, animated: true)
    }

    private func rotateOfficialAddress() {
        guard let oldIdentity = officialIdentity, !oldIdentity.isEmpty else { return }
        let replace = { [weak self] in
            guard let self else { return }
            do {
                self.officialIdentity = try OfficialPushIdentityStore.shared.reset()
                PushNotificationManager.shared.activateOfficialPush(
                    serverURL: self.officialBaseURL,
                    key: self.officialIdentity ?? ""
                ) { [weak self] result in
                    DispatchQueue.main.async {
                        self?.refresh()
                        switch result {
                        case .ready: self?.showFeedback("官方推送地址已更新")
                        case .denied: self?.showFeedback("地址已更新；请在系统设置中允许通知后接收推送")
                        case .failed(let message): self?.showError(message)
                        }
                    }
                }
            } catch {
                self.showError(error.localizedDescription)
            }
        }

        // Before APNs registration there is nothing to revoke remotely; the
        // local public identity can safely be replaced.
        guard UserDefaults.standard.bool(forKey: "com.webbridgekit.officialPush.registered") else {
            replace()
            return
        }
        PushNotificationManager.shared.revokeOfficialPush(serverURL: officialBaseURL, key: oldIdentity) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success: replace()
                case .failure(let error): self?.showError(error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Formatting helpers

    private func selfHostedText(for configuration: SelfHostedPushConfiguration) -> String {
        let baseURL = configuration.serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let address = "\(baseURL)/\(configuration.deviceKey)"
        let privacy = configuration.resolvedRelayKind == .selfHostedDirect
            ? "直连服务会在转发 APNs 前读取直接消息内容。"
            : "托管服务仅处理发送端加密后的信封，正文只在本机解密。"
        return "已添加：\(configuration.name)\n服务地址：\(configuration.serverURL)\n推送标识：\(masked(configuration.deviceKey))\n用途：\(privacy)\n完整地址可切换为当前通道后复制：\(maskedAddress(address))"
    }

    private func masked(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "尚未生成" }
        guard value.count > 8 else { return value }
        return "\(value.prefix(4))…\(value.suffix(4))"
    }

    private func maskedAddress(_ value: String) -> String {
        guard let slash = value.lastIndex(of: "/") else { return value }
        return "\(value[..<value.index(after: slash)])\(masked(String(value[value.index(after: slash)...])))"
    }

    private func sectionTitle(_ value: String) -> UILabel {
        let label = makeLabel(value, style: .headline, color: ThemeTokens.Color.text)
        return label
    }

    private func makeLabel(_ text: String, style: UIFont.TextStyle, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.numberOfLines = 0
        label.font = UIFont.preferredFont(forTextStyle: style)
        label.textColor = color
        return label
    }

    private func configureDetailLabel(_ label: UILabel) {
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.textColor = ThemeTokens.Color.textSecondary
    }

    private func configureButton(_ button: UIButton) {
        button.heightAnchor.constraint(equalToConstant: 46).isActive = true
        button.layer.cornerRadius = ThemeTokens.CornerRadius.md
        button.clipsToBounds = true
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
    }

    private func showFeedback(_ message: String) {
        HUDService.shared.showSuccess(withStatus: message)
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "无法完成操作", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default))
        present(alert, animated: true)
    }
}
