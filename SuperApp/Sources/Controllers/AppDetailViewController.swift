//
//  AppDetailViewController.swift
//  SuperApp
//
//  Created on 2026-05-09.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import SnapKit
import WebBridgeKit

class AppDetailViewController: UIViewController {

    private let item: DiscoverItem

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.alwaysBounceVertical = true
        return sv
    }()

    private let contentStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 12
        return sv
    }()

    init(item: DiscoverItem) {
        self.item = item
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.tr("discover.detail.title")
        view.backgroundColor = ThemeColors.current.background
        navigationItem.largeTitleDisplayMode = .never

        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        contentStack.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().offset(-32)
            make.width.equalTo(scrollView).offset(-32)
        }

        buildContent()
    }

    private func buildContent() {
        contentStack.addArrangedSubview(makeHeroCard())
        contentStack.addArrangedSubview(makeCacheInfoCard())
        contentStack.addArrangedSubview(makeAccessCard())
        if let token = item.pushToken, !token.isEmpty {
            contentStack.addArrangedSubview(makePushConfigCard(token: token))
        }
        contentStack.addArrangedSubview(makeActionButtons())
    }

    private func makeHeroCard() -> UIView {
        let card = makeCardView()

        let iconContainer = UIView()
        iconContainer.layer.cornerRadius = 14
        iconContainer.clipsToBounds = true
        let gradLayer = CAGradientLayer()
        gradLayer.startPoint = CGPoint(x: 0, y: 0)
        gradLayer.endPoint = CGPoint(x: 1, y: 1)
        let colors = DiscoverViewController.gradientColorsForName(item.name)
        gradLayer.colors = [colors.0.cgColor, colors.1.cgColor]
        iconContainer.layer.addSublayer(gradLayer)

        let icon = UIImageView()
        icon.contentMode = .scaleAspectFit
        icon.tintColor = .white
        icon.image = DiscoverViewController.iconForName(item.name).image(pointSize: 28)
        iconContainer.addSubview(icon)

        iconContainer.snp.makeConstraints { make in
            make.width.height.equalTo(56)
        }
        gradLayer.frame = CGRect(x: 0, y: 0, width: 56, height: 56)
        icon.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(28)
        }

        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 4

        let nameLabel = UILabel()
        nameLabel.font = .systemFont(ofSize: 20, weight: .bold)
        nameLabel.textColor = ThemeColors.current.text
        nameLabel.text = item.name

        let idLabel = UILabel()
        idLabel.font = .systemFont(ofSize: 13, weight: .regular)
        idLabel.textColor = ThemeColors.current.textSecondary
        idLabel.text = item.bundleID ?? "com.example.app"

        textStack.addArrangedSubview(nameLabel)
        textStack.addArrangedSubview(idLabel)

        let hStack = UIStackView(arrangedSubviews: [iconContainer, textStack])
        hStack.axis = .horizontal
        hStack.alignment = .center
        hStack.spacing = 16

        card.addSubview(hStack)
        hStack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
        }

        return card
    }

    private func makeCacheInfoCard() -> UIView {
        let card = makeCardView()

        let titleLabel = makeSectionTitle(L10n.tr("discover.detail.cache_info"))

        let rows = UIStackView()
        rows.axis = .vertical
        rows.spacing = 0

        let typeValue = item.cacheStatus.displayText
        addRow(to: rows, label: L10n.tr("discover.detail.type"), value: typeValue, valueColor: item.cacheStatus.color)
        addRow(to: rows, label: L10n.tr("discover.detail.size"), value: item.cacheSize)
        addRow(to: rows, label: L10n.tr("discover.detail.version"), value: item.version ?? "-")
        addRow(to: rows, label: L10n.tr("discover.detail.resources"), value: item.resourceCount ?? "-")
        addRow(to: rows, label: L10n.tr("discover.detail.cached"), value: item.cachedDate ?? "-", isLast: true)
        addRow(to: rows, label: L10n.tr("discover.detail.expires"), value: item.expiresText ?? "-", isLast: true)

        let stack = UIStackView(arrangedSubviews: [titleLabel, rows])
        stack.axis = .vertical

        card.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
        }

        return card
    }

    private func makeAccessCard() -> UIView {
        let card = makeCardView()

        let titleLabel = makeSectionTitle(L10n.tr("discover.detail.access"))

        let rows = UIStackView()
        rows.axis = .vertical
        rows.spacing = 0

        addRow(to: rows, label: L10n.tr("discover.detail.visits"), value: item.visitCount ?? "-")
        addRow(to: rows, label: L10n.tr("discover.detail.last_visit"), value: item.lastVisit ?? "-")
        addRow(to: rows, label: L10n.tr("discover.detail.source"), value: item.sourceText ?? "-", isLast: true)

        let stack = UIStackView(arrangedSubviews: [titleLabel, rows])
        stack.axis = .vertical

        card.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
        }

        return card
    }

    private func makePushConfigCard(token: String) -> UIView {
        let card = makeCardView()

        let titleLabel = makeSectionTitle(L10n.tr("discover.detail.push_config"))

        let rows = UIStackView()
        rows.axis = .vertical
        rows.spacing = 0

        let maskedToken: String
        if token.count > 8 {
            maskedToken = String(token.prefix(4)) + "****" + String(token.suffix(4))
        } else {
            maskedToken = token
        }
        addRow(to: rows, label: L10n.tr("discover.detail.token"), value: maskedToken, isLast: true, mono: true)

        let btnStack = UIStackView()
        btnStack.spacing = 8
        btnStack.snp.makeConstraints { make in
            make.height.equalTo(36)
        }

        let copyBtn = makeSmallButton(title: L10n.tr("discover.detail.copy"), icon: .copy, style: .primary)
        copyBtn.addTarget(self, action: #selector(copyToken(_:)), for: .touchUpInside)
        btnStack.addArrangedSubview(copyBtn)

        let urlBtn = makeSmallButton(title: L10n.tr("discover.detail.url"), icon: .link, style: .outline)
        urlBtn.addTarget(self, action: #selector(copyPushURL(_:)), for: .touchUpInside)
        btnStack.addArrangedSubview(urlBtn)

        let stack = UIStackView(arrangedSubviews: [titleLabel, rows, btnStack])
        stack.axis = .vertical
        stack.spacing = 8

        card.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
        }

        return card
    }

    private func makeActionButtons() -> UIView {
        let stack = UIStackView()
        stack.spacing = 8
        stack.distribution = .fillEqually

        let refreshBtn = makeSmallButton(title: L10n.tr("discover.detail.refresh"), icon: .refresh, style: .primary)
        refreshBtn.addTarget(self, action: #selector(refreshAction(_:)), for: .touchUpInside)

        let clearBtn = makeSmallButton(title: L10n.tr("discover.detail.clear"), icon: .trash, style: .danger)
        clearBtn.addTarget(self, action: #selector(clearAction(_:)), for: .touchUpInside)

        let openBtn = makeSmallButton(title: L10n.tr("discover.detail.open"), icon: .arrowRight, style: .success)
        openBtn.addTarget(self, action: #selector(openAction(_:)), for: .touchUpInside)

        stack.addArrangedSubview(refreshBtn)
        stack.addArrangedSubview(clearBtn)
        stack.addArrangedSubview(openBtn)

        stack.snp.makeConstraints { make in
            make.height.equalTo(40)
        }

        return stack
    }

    // MARK: - Actions

    @objc private func copyToken(_ sender: UIButton) {
        if let token = item.pushToken {
            UIPasteboard.general.string = token
            showAlert(title: L10n.tr("common.success"), message: L10n.tr("discover.detail.token_copied"))
        }
    }

    @objc private func copyPushURL(_ sender: UIButton) {
        if let token = item.pushToken {
            let urlString = "https://api.day.app/\(token)"
            UIPasteboard.general.string = urlString
            showAlert(title: L10n.tr("common.success"), message: L10n.tr("discover.detail.url_copied"))
        }
    }

    @objc private func refreshAction(_ sender: UIButton) {
        showAlert(title: L10n.tr("discover.detail.refreshing"), message: L10n.tr("discover.detail.refresh_msg"))
    }

    @objc private func clearAction(_ sender: UIButton) {
        if let url = URL(string: item.url) {
            PersistentManifestLoader.shared.clearCache(for: url)
        }
        showAlert(title: L10n.tr("common.success"), message: L10n.tr("discover.detail.cleared"))
    }

    @objc private func openAction(_ sender: UIButton) {
        guard let url = URL(string: item.url) else { return }
        WebBrowserManager.shared.openBrowser(
            url: url,
            params: WebBrowserParams(displayMode: .normal),
            from: navigationController
        )
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.tr("common.ok"), style: .default))
        present(alert, animated: true)
    }

    // MARK: - Factory Helpers

    private func makeCardView() -> UIView {
        let view = UIView()
        view.backgroundColor = ThemeColors.current.cardBackground
        view.layer.cornerRadius = 14
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 8
        view.layer.shadowOpacity = 0.06
        return view
    }

    private func makeSectionTitle(_ text: String) -> UILabel {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = ThemeColors.current.textSecondary
        label.text = text.uppercased()
        return label
    }

    private func addRow(to stack: UIStackView, label: String, value: String, valueColor: UIColor? = nil, isLast: Bool = false, mono: Bool = false) {
        let container = UIView()

        let lb = UILabel()
        lb.font = .systemFont(ofSize: 14, weight: .regular)
        lb.textColor = ThemeColors.current.textSecondary
        lb.text = label

        let vl = UILabel()
        vl.font = mono ? .monospacedSystemFont(ofSize: 13, weight: .regular) : .systemFont(ofSize: 14, weight: .regular)
        vl.textColor = valueColor ?? ThemeColors.current.text
        vl.textAlignment = .right
        vl.text = value

        container.addSubview(lb)
        container.addSubview(vl)

        lb.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.top.bottom.equalToSuperview().inset(10)
        }

        vl.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.centerY.equalTo(lb)
            make.leading.greaterThanOrEqualTo(lb.snp.trailing).offset(8)
        }

        if !isLast {
            let sep = UIView()
            sep.backgroundColor = ThemeColors.current.divider
            container.addSubview(sep)
            sep.snp.makeConstraints { make in
                make.leading.trailing.bottom.equalToSuperview()
                make.height.equalTo(0.5)
            }
        }

        stack.addArrangedSubview(container)
    }

    private enum ButtonStyle {
        case primary, danger, success, outline
    }

    private func makeSmallButton(title: String, icon: LucideIcon, style: ButtonStyle) -> UIButton {
        let btn = UIButton(type: .system)

        let bgColor: UIColor
        let fgColor: UIColor
        switch style {
        case .primary:
            bgColor = UIColor(red: 0, green: 0.478, blue: 1, alpha: 1)
            fgColor = .white
        case .danger:
            bgColor = UIColor(red: 1, green: 0.231, blue: 0.188, alpha: 1)
            fgColor = .white
        case .success:
            bgColor = UIColor(red: 0.204, green: 0.78, blue: 0.349, alpha: 1)
            fgColor = .white
        case .outline:
            bgColor = .clear
            fgColor = UIColor(red: 0, green: 0.478, blue: 1, alpha: 1)
        }

        btn.backgroundColor = bgColor
        btn.setTitleColor(fgColor, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        btn.setTitle(title, for: .normal)
        btn.setImage(icon.image(pointSize: 14), for: .normal)
        btn.tintColor = fgColor
        btn.layer.cornerRadius = 8
        if case .outline = style {
            btn.layer.borderWidth = 1.5
            btn.layer.borderColor = UIColor(red: 0, green: 0.478, blue: 1, alpha: 1).cgColor
        }
        btn.imageView?.contentMode = .scaleAspectFit
        btn.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        btn.titleEdgeInsets = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 0)
        btn.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 4)

        return btn
    }
}

// MARK: - DiscoverViewController helpers exposed for AppDetailViewController

extension DiscoverViewController {
    static func gradientColorsForName(_ name: String) -> (UIColor, UIColor) {
        let gradients: [(UIColor, UIColor)] = [
            (UIColor(red: 0.4, green: 0.494, blue: 0.918, alpha: 1), UIColor(red: 0.463, green: 0.294, blue: 0.635, alpha: 1)),
            (UIColor(red: 0.941, green: 0.576, blue: 0.984, alpha: 1), UIColor(red: 0.961, green: 0.341, blue: 0.424, alpha: 1)),
            (UIColor(red: 0.31, green: 0.673, blue: 0.996, alpha: 1), UIColor(red: 0, green: 0.949, blue: 0.996, alpha: 1)),
            (UIColor(red: 0.263, green: 0.914, blue: 0.482, alpha: 1), UIColor(red: 0.22, green: 0.976, blue: 0.843, alpha: 1)),
            (UIColor(red: 0.98, green: 0.439, blue: 0.604, alpha: 1), UIColor(red: 0.996, green: 0.882, blue: 0.251, alpha: 1)),
            (UIColor(red: 0.631, green: 0.549, blue: 0.82, alpha: 1), UIColor(red: 0.984, green: 0.761, blue: 0.922, alpha: 1)),
        ]
        return gradients[abs(name.hashValue) % gradients.count]
    }

    static func iconForName(_ name: String) -> LucideIcon {
        let icons: [LucideIcon] = [.globe, .appFill, .hardDrive, .doc, .star, .folder]
        return icons[abs(name.hashValue) % icons.count]
    }
}
