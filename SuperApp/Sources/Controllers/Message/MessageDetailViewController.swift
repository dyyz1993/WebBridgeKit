//
//  MessageDetailViewController.swift
//  SuperApp
//
//  Created on 2026-05-07.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import SnapKit
import WebKit
import WebBridgeKit
import CoreImage
import CoreImage.CIFilterBuiltins

class MessageDetailViewController: UIViewController, UIGestureRecognizerDelegate {

    let message: StoredMessage
    private let launchResolver = HTMLAppLaunchResolver()

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.alwaysBounceVertical = true
        return sv
    }()

    private let contentStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = ThemeTokens.Spacing.md
        return stack
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.title2
        label.textColor = ThemeTokens.Color.text
        label.numberOfLines = 0
        return label
    }()

    private let webView: WKWebView = {
        let config = WKWebViewConfiguration()
        let webview = WKWebView(frame: .zero, configuration: config)
        webview.isOpaque = false
        webview.scrollView.isScrollEnabled = false
        webview.contentMode = .scaleToFill
        return webview
    }()

    private var markdownHeightConstraint: Constraint?
    weak var approvalStateValueLabel: UILabel?
    var isSubmittingApproval = false

    private let bodyLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.body
        label.textColor = ThemeTokens.Color.textSecondary
        label.numberOfLines = 0
        label.accessibilityIdentifier = "message.detail.body"
        return label
    }()

    private let metaCard: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeTokens.Color.cardBackground
        view.layer.cornerRadius = ThemeTokens.CornerRadius.md
        view.accessibilityIdentifier = "message.detail.metadata"
        return view
    }()

    private let metaStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = ThemeTokens.Spacing.sm
        return stack
    }()

    private let technicalMetaCard: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeTokens.Color.cardBackground
        view.layer.cornerRadius = ThemeTokens.CornerRadius.md
        view.accessibilityIdentifier = "message.detail.technical"
        view.isHidden = true
        return view
    }()

    private let technicalMetaStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = ThemeTokens.Spacing.sm
        return stack
    }()

    private let technicalToggleButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(L10n.tr("message.detail.technical_info"), for: .normal)
        button.setImage(LucideIcon.chevronDown.templateImage(pointSize: 16), for: .normal)
        button.tintColor = ThemeTokens.Color.textSecondary
        button.setTitleColor(ThemeTokens.Color.textSecondary, for: .normal)
        button.titleLabel?.font = ThemeTokens.Typography.metadata
        button.contentHorizontalAlignment = .leading
        button.semanticContentAttribute = .forceRightToLeft
        button.accessibilityIdentifier = "message.detail.technical.toggle"
        button.accessibilityValue = "collapsed"
        button.isHidden = true
        return button
    }()

    let contextualActionStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = ThemeTokens.Spacing.sm
        stack.isHidden = true
        return stack
    }()

    let destinationActionStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = ThemeTokens.Spacing.sm
        stack.isHidden = true
        return stack
    }()

    let secondaryActionStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = ThemeTokens.Spacing.sm
        stack.isHidden = true
        return stack
    }()

    /// Ordered peer messages of the inbox view that opened this detail;
    /// enables next/previous navigation. Nil disables navigation.
    private let peerMessages: [StoredMessage]?
    private var currentIndex: Int

    init(message: StoredMessage, peerMessages: [StoredMessage]? = nil) {
        self.message = message
        self.peerMessages = peerMessages
        self.currentIndex = peerMessages?.firstIndex(where: { $0.id == message.id }) ?? 0
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = message.bodyType == "markdown"
            ? message.payload.title
            : L10n.tr("message.detail.title")
        view.backgroundColor = ThemeTokens.Color.background
        scrollView.accessibilityIdentifier = "message.detail"
        webView.accessibilityIdentifier = "message.detail.markdown"
        setupUI()
        configure()
        setupSideIndicators()
        setupSwipeNavigation()
    }

    // MARK: - Peer navigation (next/previous)

    // MARK: - Swipe navigation indicators

    /// Subtle side chevrons: left = swipe left for the next message,
    /// right = swipe right for the previous one. The left indicator also
    /// carries the unread red dot (next message unread).
    private let nextIndicator: UIImageView = {
        let iv = UIImageView()
        iv.image = LucideIcon.chevronLeft.templateImage(pointSize: ThemeTokens.Icons.Sizes.sm)
        iv.tintColor = ThemeTokens.Color.textTertiary
        iv.alpha = 0.45
        iv.contentMode = .scaleAspectFit
        iv.isUserInteractionEnabled = false
        iv.accessibilityIdentifier = "message.detail.indicator.next"
        return iv
    }()

    private let prevIndicator: UIImageView = {
        let iv = UIImageView()
        iv.image = LucideIcon.chevronRight.templateImage(pointSize: ThemeTokens.Icons.Sizes.sm)
        iv.tintColor = ThemeTokens.Color.textTertiary
        iv.alpha = 0.45
        iv.contentMode = .scaleAspectFit
        iv.isUserInteractionEnabled = false
        iv.accessibilityIdentifier = "message.detail.indicator.prev"
        return iv
    }()

    private let nextUnreadDot: UIView = {
        let dot = UIView()
        dot.backgroundColor = ThemeTokens.Color.error
        dot.layer.cornerRadius = 3
        dot.isHidden = true
        dot.isUserInteractionEnabled = false
        dot.accessibilityIdentifier = "message.detail.next.unread"
        return dot
    }()

    private func setupSideIndicators() {
        guard peerMessages != nil else { return }
        view.addSubview(nextIndicator)
        view.addSubview(prevIndicator)
        view.addSubview(nextUnreadDot)
        nextIndicator.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(ThemeTokens.Spacing.xxs)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(ThemeTokens.Icons.Sizes.sm)
        }
        prevIndicator.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-ThemeTokens.Spacing.xxs)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(ThemeTokens.Icons.Sizes.sm)
        }
        nextUnreadDot.snp.makeConstraints { make in
            make.centerX.equalTo(nextIndicator.snp.leading)
            make.top.equalTo(nextIndicator.snp.top).offset(-4)
            make.width.height.equalTo(6)
        }
        refreshNavigationState()
    }

    private func refreshNavigationState() {
        guard let peers = peerMessages else { return }
        nextIndicator.isHidden = currentIndex >= peers.count - 1
        prevIndicator.isHidden = currentIndex <= 0
        let hasNext = currentIndex < peers.count - 1
        nextUnreadDot.isHidden = !(hasNext && !peers[currentIndex + 1].isRead)
    }

    /// Horizontal swipe navigation: left = next message (mark read and
    /// advance), right = previous. Horizontal pans are unused in the detail
    /// (its content scrolls vertically), so they can drive navigation the
    /// way mail apps do. The system edge-back gesture keeps the screen edge
    /// for exiting the detail.
    private func setupSwipeNavigation() {
        guard peerMessages != nil else { return }
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleNavigationPan(_:)))
        pan.delegate = self
        if let edgePan = navigationController?.interactivePopGestureRecognizer {
            // Edge swipes belong to the system back gesture; waiting for it
            // to fail keeps mid-screen right-swipes (previous message) from
            // racing the pop.
            pan.require(toFail: edgePan)
        }
        view.addGestureRecognizer(pan)
    }

    @objc private func handleNavigationPan(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .changed:
            let x = gesture.translation(in: view).x
            // The page follows the finger: translate the scroll view with a
            // slight rotation (Tinder-card feel) and rubber-band at the edges
            // where there is no peer to navigate to.
            let bounded = rubberBand(x)
            let rotation = bounded * 0.0004
            scrollView.transform = CGAffineTransform(
                translationX: bounded, y: 0
            ).rotated(by: rotation)
            // Brighten the indicator the drag is heading toward.
            nextIndicator.alpha = x < 0 ? 1.0 : 0.45
            prevIndicator.alpha = x > 0 ? 1.0 : 0.45
        case .ended, .cancelled, .failed:
            let translation = gesture.translation(in: view)
            let velocity = gesture.velocity(in: view)
            let shouldAdvanceNext = -translation.x > 80 || -velocity.x > 800
            let shouldAdvancePrev = translation.x > 80 || velocity.x > 800
            if shouldAdvanceNext || shouldAdvancePrev {
                // Fly the current page out in the swipe direction, then swap.
                let flyDirection: CGFloat = shouldAdvanceNext ? -1 : 1
                UIView.animate(
                    withDuration: ThemeTokens.Animation.normal.duration,
                    delay: 0,
                    options: [.curveEaseIn],
                    animations: {
                        self.scrollView.transform = CGAffineTransform(
                            translationX: flyDirection * self.view.bounds.width,
                            y: 0
                        ).rotated(by: flyDirection * 0.15)
                        self.scrollView.alpha = 0
                    },
                    completion: { [weak self] _ in
                        guard let self = self else { return }
                        self.scrollView.transform = .identity
                        self.scrollView.alpha = 1
                        self.advance(toOffset: shouldAdvanceNext ? 1 : -1)
                    }
                )
            } else {
                // Below threshold: spring back to center.
                UIView.animate(
                    withDuration: ThemeTokens.Animation.modal.duration,
                    delay: 0,
                    usingSpringWithDamping: 0.8,
                    initialSpringVelocity: 0.3,
                    animations: {
                        self.scrollView.transform = .identity
                    }
                )
            }
            nextIndicator.alpha = 0.45
            prevIndicator.alpha = 0.45
        default:
            break
        }
    }

    /// Rubber-bands the horizontal translation at the boundaries (no peer to
    /// navigate to in that direction), so the page feels tethered.
    private func rubberBand(_ x: CGFloat) -> CGFloat {
        let width = view.bounds.width
        let maxPull = width * 0.35
        let canGoLeft = currentIndex < (peerMessages?.count ?? 0) - 1
        let canGoRight = currentIndex > 0
        if x < 0 && !canGoLeft { return -damped(-x, max: maxPull) }
        if x > 0 && !canGoRight { return damped(x, max: maxPull) }
        return x
    }

    private func damped(_ value: CGFloat, max: CGFloat) -> CGFloat {
        max * (1 - 1 / (value / max + 1))
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        let velocity = pan.velocity(in: view)
        return abs(velocity.x) > abs(velocity.y) * 1.5
    }

    private func advance(toOffset offset: Int) {
        guard let peers = peerMessages else { return }
        let target = currentIndex + offset
        guard peers.indices.contains(target) else { return }
        let targetMessage = peers[target]
        if !targetMessage.isRead {
            Task { await MessageEngine.shared.markAsRead(id: targetMessage.id) }
        }
        let replacement = MessageDetailViewController(message: targetMessage, peerMessages: peers)
        guard let navigationController = navigationController else { return }
        // Replace the top of the stack instead of pushing: reviewing many
        // messages must not pile up history that Back would walk through.
        // The swap itself is never animated through UIKit: programmatic stack
        // surgery with animated transitions (or a parked-then-pop trick)
        // desynchronizes the interactivePopGestureRecognizer, which killed
        // the edge-swipe back entirely. Instead, take a snapshot of the old
        // screen, swap instantly, and slide the snapshot out in the swipe's
        // direction — the transition feels native and navigation stays sane.
        var stack = navigationController.viewControllers
        stack[stack.count - 1] = replacement
        let snapshot = navigationController.view.snapshotView(afterScreenUpdates: false)
        navigationController.setViewControllers(stack, animated: false)
        guard let snapshot else { return }
        navigationController.view.addSubview(snapshot)
        snapshot.frame = navigationController.view.bounds
        let width = navigationController.view.bounds.width
        let exitOffset: CGFloat = offset > 0 ? -width : width
        UIView.animate(
            withDuration: ThemeTokens.Animation.normal.duration + 0.05,
            delay: 0,
            options: [.curveEaseOut],
            animations: {
                snapshot.frame.origin.x = exitOffset
            },
            completion: { _ in
                snapshot.removeFromSuperview()
            }
        )
    }

    private func setupUI() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentStackView)

        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }

        contentStackView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().offset(-16)
            make.width.equalTo(scrollView).offset(-32)
        }

        if message.bodyType != "markdown" {
            contentStackView.addArrangedSubview(titleLabel)
        }

        if message.payload.actionState != nil
            || message.payload.contentType == .approval
            || ["approval", "permission"].contains(message.payload.category?.lowercased() ?? "") {
            contentStackView.addArrangedSubview(makeApprovalStateCard())
        }

        if let verificationCode = message.payload.verificationCode {
            contentStackView.addArrangedSubview(
                makeVerificationCodeCard(code: verificationCode, expiresAt: message.payload.expiresAt)
            )
        }

        if let qrPayload = message.payload.qrPayload, !qrPayload.isEmpty {
            contentStackView.addArrangedSubview(makeQRCodeCard(payload: qrPayload))
        }

        contentStackView.addArrangedSubview(contextualActionStackView)

        if message.payload.imageURL != nil {
            contentStackView.addArrangedSubview(makeMediaCard())
        }

        if message.bodyType == "markdown" {
            contentStackView.addArrangedSubview(webView)
            webView.snp.makeConstraints { make in
                markdownHeightConstraint = make.height.equalTo(100).constraint
            }
        } else {
            contentStackView.addArrangedSubview(bodyLabel)
        }

        contentStackView.addArrangedSubview(destinationActionStackView)
        contentStackView.addArrangedSubview(metaCard)
        contentStackView.addArrangedSubview(technicalToggleButton)
        contentStackView.addArrangedSubview(technicalMetaCard)
        contentStackView.addArrangedSubview(secondaryActionStackView)

        metaCard.addSubview(metaStackView)
        metaStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
        }

        technicalToggleButton.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(44)
        }
        technicalToggleButton.addTarget(self, action: #selector(toggleTechnicalMetadata), for: .touchUpInside)

        technicalMetaCard.addSubview(technicalMetaStackView)
        technicalMetaStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
        }
    }

    private func configure() {
        titleLabel.text = message.payload.title

        if message.bodyType == "markdown" {
            let markdownContent = message.payload.markdown ?? message.payload.body
            let html = MarkdownRenderer.renderHTML(
                title: message.payload.title,
                markdown: markdownContent
            )
            webView.loadHTMLString(html, baseURL: nil)
            webView.navigationDelegate = self
        } else {
            bodyLabel.text = message.payload.body
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        addMetaRow(label: L10n.tr("message.detail.received_time"), value: formatter.string(from: message.receivedAt))
        addMetaRow(label: L10n.tr("message.detail.source"), value: message.payload.channel)
        if let group = message.payload.group {
            addMetaRow(label: L10n.tr("message.detail.group"), value: group)
        }
        if let level = message.payload.interruptionLevel {
            addMetaRow(label: L10n.tr("message.detail.interruption"), value: level.displayName)
        }
        if let sound = message.payload.sound {
            let volume = message.payload.soundVolume.map { " · \(Int($0))/10" } ?? ""
            addMetaRow(label: L10n.tr("message.detail.sound"), value: "\(sound)\(volume)")
        }
        if message.payload.isCall == true {
            addMetaRow(label: L10n.tr("message.detail.call"), value: L10n.tr("message.detail.enabled"))
        }
        if let route = message.payload.route {
            addTechnicalMetaRow(label: L10n.tr("message.detail.route"), value: route)
        }
        if let expirationDate = message.payload.expirationDate {
            addMetaRow(
                label: L10n.tr("message.detail.expiry"),
                value: message.payload.isExpired
                    ? L10n.tr("message.detail.expired")
                    : formatter.string(from: expirationDate)
            )
        }
        if message.payload.isArchive == true {
            addTechnicalMetaRow(label: L10n.tr("message.detail.archive"), value: L10n.tr("message.detail.enabled"))
        }
        if let replacementID = message.payload.replacementID {
            addTechnicalMetaRow(label: L10n.tr("message.detail.replace_id"), value: replacementID)
        }
        if let requestID = message.payload.requestID {
            addTechnicalMetaRow(label: L10n.tr("message.detail.request_id"), value: requestID)
        }
        if let statePath = message.payload.statePath {
            addTechnicalMetaRow(label: L10n.tr("message.detail.state_path"), value: statePath)
        }
        if let revision = message.payload.revision {
            addTechnicalMetaRow(label: L10n.tr("message.detail.revision"), value: String(revision))
        }
        if message.isRead, let readAt = message.readAt {
            addMetaRow(label: L10n.tr("message.detail.read_time"), value: formatter.string(from: readAt))
        }

        let bodyToCopy = message.bodyType == "markdown"
            ? (message.payload.markdown ?? message.payload.body)
            : message.payload.body

        if let verificationCode = message.payload.verificationCode {
            addAction(
                title: L10n.tr("message.detail.copy_verification_code"),
                icon: .copy,
                placement: .contextual,
                style: .accent,
                accessibilityIdentifier: "message.detail.copyVerificationCode"
            ) {
                UIPasteboard.general.string = verificationCode
                HUDService.shared.showSuccess(withStatus: L10n.tr("message.detail.verification_copied"))
            }
        }

        if let copyText = message.payload.copyText,
           !copyText.isEmpty,
           copyText != message.payload.verificationCode,
           copyText != message.payload.qrPayload {
            addAction(
                title: L10n.tr("message.detail.copy_value"),
                icon: .copy,
                placement: .secondary,
                accessibilityIdentifier: "message.detail.copyValue"
            ) {
                UIPasteboard.general.string = copyText
                HUDService.shared.showSuccess(withStatus: L10n.tr("message.detail.copied"))
            }
        }

        if let qrPayload = message.payload.qrPayload, !qrPayload.isEmpty, qrPayload != message.payload.copyText {
            addAction(
                title: L10n.tr("message.detail.copy_qr_value"),
                icon: .copy,
                placement: .contextual,
                style: .accent,
                accessibilityIdentifier: "message.detail.copyQRValue"
            ) {
                UIPasteboard.general.string = qrPayload
                HUDService.shared.showSuccess(withStatus: L10n.tr("message.detail.copied"))
            }
        }

        if message.payload.qrPayload?.isEmpty != false {
            addAction(
                title: L10n.tr("message.detail.copy_content"),
                icon: .copy,
                placement: .secondary
            ) {
                UIPasteboard.general.string = bodyToCopy
                HUDService.shared.showSuccess(withStatus: L10n.tr("message.detail.copied"))
            }
        }

        configureNativeApprovalActions()

        if let urlString = message.payload.targetURL, let url = URL(string: urlString) {
            addAction(
                title: L10n.tr("message.detail.open_link"),
                icon: .link,
                placement: .destination,
                style: .primary
            ) { [weak self] in
                guard let self = self else { return }
                WebBrowserManager.shared.openBrowser(
                    url: url,
                    params: WebBrowserParams(payload: self.message.payload.userInfo),
                    from: self
                )
            }
        }

        if let appId = message.payload.targetAppId {
            let isApproval = message.payload.contentType == .approval
                || ["approval", "permission"].contains(message.payload.category?.lowercased() ?? "")
            let isChat = message.payload.contentType == .chat
            let actionTitle: String
            if isApproval {
                actionTitle = L10n.tr("message.detail.open_approval")
            } else if isChat {
                actionTitle = L10n.tr("message.detail.open_conversation")
            } else {
                actionTitle = L10n.tr("message.detail.open_app")
            }
            addAction(
                title: actionTitle,
                icon: .appBadge,
                placement: isApproval ? .contextual : .destination,
                style: .primary,
                accessibilityIdentifier: isChat ? "message.detail.openConversation" : "message.detail.openApp"
            ) { [weak self] in
                self?.openHTMLApp(appID: appId)
            }
        }

        addAction(
            title: L10n.tr("common.delete"),
            icon: .trash,
            placement: .secondary,
            style: .destructive
        ) { [weak self] in
            guard let self = self else { return }
            let alert = UIAlertController(title: L10n.tr("message.detail.confirm_delete_title"), message: L10n.tr("message.detail.confirm_delete_message"), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L10n.tr("common.cancel"), style: .cancel))
            alert.addAction(UIAlertAction(title: L10n.tr("common.delete"), style: .destructive) { _ in
                Task {
                    await MessageEngine.shared.deleteMessage(id: self.message.id)
                    self.navigationController?.popViewController(animated: true)
                }
            })
            self.present(alert, animated: true)
        }
    }

    private func addMetaRow(label: String, value: String) {
        addMetaRow(label: label, value: value, to: metaStackView)
    }

    private func addTechnicalMetaRow(label: String, value: String) {
        addMetaRow(label: label, value: value, to: technicalMetaStackView)
        technicalToggleButton.isHidden = false
    }

    private func addMetaRow(label: String, value: String, to stackView: UIStackView) {
        let container = UIView()
        let labelLabel = UILabel()
        labelLabel.text = label
        labelLabel.font = ThemeTokens.Typography.footnote
        labelLabel.textColor = ThemeTokens.Color.textSecondary
        labelLabel.setContentHuggingPriority(.required, for: .horizontal)

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = ThemeTokens.Typography.footnote
        valueLabel.textColor = ThemeTokens.Color.textSecondary
        valueLabel.numberOfLines = 0

        container.addSubview(labelLabel)
        container.addSubview(valueLabel)

        labelLabel.snp.makeConstraints { make in
            make.top.leading.bottom.equalToSuperview()
            make.width.equalTo(70)
        }

        valueLabel.snp.makeConstraints { make in
            make.top.trailing.bottom.equalToSuperview()
            make.leading.equalTo(labelLabel.snp.trailing).offset(8)
        }

        stackView.addArrangedSubview(container)
    }

    @objc private func toggleTechnicalMetadata() {
        let willExpand = technicalMetaCard.isHidden
        technicalMetaCard.isHidden = !willExpand
        technicalToggleButton.accessibilityValue = willExpand ? "expanded" : "collapsed"
        UIView.animate(withDuration: 0.2) {
            self.technicalToggleButton.imageView?.transform = willExpand
                ? CGAffineTransform(rotationAngle: .pi)
                : .identity
            self.contentStackView.layoutIfNeeded()
        }
    }

    private func makeVerificationCodeCard(code: String, expiresAt: Date?) -> UIView {
        let card = UIView()
        card.backgroundColor = ThemeTokens.Color.primarySoft
        card.layer.cornerRadius = ThemeTokens.CornerRadius.md
        card.accessibilityIdentifier = "message.detail.verificationCode"

        let title = UILabel()
        title.font = ThemeTokens.Typography.metadata
        title.textColor = ThemeTokens.Color.primary
        title.text = L10n.tr("message.detail.verification_code")

        let codeLabel = UILabel()
        codeLabel.font = ThemeTokens.Typography.title1
        codeLabel.textColor = ThemeTokens.Color.text
        codeLabel.text = code
        codeLabel.accessibilityIdentifier = "message.detail.verificationCode.value"

        let expiration = UILabel()
        expiration.font = ThemeTokens.Typography.metadata
        expiration.textColor = message.payload.isExpired ? ThemeTokens.Color.error : ThemeTokens.Color.textSecondary
        if message.payload.isExpired {
            expiration.text = L10n.tr("message.detail.verification_expired")
        } else if let expiresAt {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            expiration.text = L10n.tr("message.detail.verification_expires_at", formatter.string(from: expiresAt))
        }

        let stack = UIStackView(arrangedSubviews: [title, codeLabel, expiration])
        stack.axis = .vertical
        stack.spacing = ThemeTokens.Spacing.xs
        card.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(ThemeTokens.Spacing.lg)
        }

        return card
    }

    private func makeApprovalStateCard() -> UIView {
        let card = UIView()
        let presentation = approvalStatePresentation()
        card.backgroundColor = presentation.color.withAlphaComponent(0.10)
        card.layer.cornerRadius = ThemeTokens.CornerRadius.md
        card.accessibilityIdentifier = "message.detail.approvalState"

        let icon = UIImageView(image: presentation.icon.templateImage(pointSize: ThemeTokens.Icons.Sizes.md))
        icon.tintColor = presentation.color
        icon.contentMode = .scaleAspectFit

        let title = UILabel()
        title.font = ThemeTokens.Typography.sectionTitle
        title.textColor = ThemeTokens.Color.text
        title.text = presentation.title
        title.accessibilityIdentifier = "message.detail.approvalState.value"
        approvalStateValueLabel = title

        let note = UILabel()
        note.font = ThemeTokens.Typography.footnote
        note.textColor = ThemeTokens.Color.textSecondary
        note.numberOfLines = 0
        note.text = message.payload.presentation == .native
            ? L10n.tr("message.detail.approval_native_note")
            : L10n.tr("message.detail.approval_safety_note")

        let labels = UIStackView(arrangedSubviews: [title, note])
        labels.axis = .vertical
        labels.spacing = ThemeTokens.Spacing.xs

        card.addSubview(icon)
        card.addSubview(labels)
        icon.snp.makeConstraints { make in
            make.leading.top.equalToSuperview().inset(ThemeTokens.Spacing.lg)
            make.width.height.equalTo(ThemeTokens.Icons.Sizes.md)
        }
        labels.snp.makeConstraints { make in
            make.leading.equalTo(icon.snp.trailing).offset(ThemeTokens.Spacing.md)
            make.top.bottom.trailing.equalToSuperview().inset(ThemeTokens.Spacing.lg)
        }
        return card
    }

    func approvalStatePresentation() -> (title: String, icon: LucideIcon, color: UIColor) {
        switch message.payload.actionState {
        case .pending:
            return (L10n.tr("message.action.pending"), .clock, ThemeTokens.Color.warning)
        case .approved:
            return (L10n.tr("message.action.approved"), .success, ThemeTokens.Color.success)
        case .rejected:
            return (L10n.tr("message.action.rejected"), .warning, ThemeTokens.Color.error)
        case .cancelled:
            return (L10n.tr("message.action.cancelled"), .clipboard, ThemeTokens.Color.textSecondary)
        case .expired:
            return (L10n.tr("message.action.expired"), .clock, ThemeTokens.Color.textSecondary)
        case nil:
            return (L10n.tr("message.action.unspecified"), .clipboard, ThemeTokens.Color.textSecondary)
        @unknown default:
            return (L10n.tr("message.action.unspecified"), .clipboard, ThemeTokens.Color.textSecondary)
        }
    }

    private func makeQRCodeCard(payload: String) -> UIView {
        let card = UIView()
        card.backgroundColor = ThemeTokens.Color.surface
        card.layer.cornerRadius = ThemeTokens.CornerRadius.md
        card.accessibilityIdentifier = "message.detail.qrCode"

        let imageView = UIImageView(image: makeQRCodeImage(payload: payload))
        imageView.contentMode = .scaleAspectFit
        imageView.accessibilityLabel = L10n.tr("message.detail.qr_code")

        let title = UILabel()
        title.font = ThemeTokens.Typography.sectionTitle
        title.textColor = ThemeTokens.Color.text
        title.text = L10n.tr("message.detail.qr_code")

        let value = UILabel()
        value.font = ThemeTokens.Typography.metadata
        value.textColor = ThemeTokens.Color.textSecondary
        value.numberOfLines = 2
        value.lineBreakMode = .byTruncatingMiddle
        value.text = payload

        let labels = UIStackView(arrangedSubviews: [title, value])
        labels.axis = .vertical
        labels.spacing = ThemeTokens.Spacing.xs

        card.addSubview(imageView)
        card.addSubview(labels)
        imageView.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview().inset(ThemeTokens.Spacing.lg)
            make.width.height.equalTo(96)
        }
        labels.snp.makeConstraints { make in
            make.leading.equalTo(imageView.snp.trailing).offset(ThemeTokens.Spacing.lg)
            make.trailing.equalToSuperview().inset(ThemeTokens.Spacing.lg)
            make.centerY.equalTo(imageView)
        }
        return card
    }

    private func makeQRCodeImage(payload: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)) else {
            return nil
        }
        let context = CIContext(options: nil)
        guard let image = context.createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: image)
    }

    private func makeMediaCard() -> UIView {
        let card = MessageMediaCardView()
        if let source = message.payload.imageURL {
            card.load(source: source)
        }
        return card
    }

    private func openHTMLApp(appID: String) {
        if let route = message.payload.route {
            do {
                let target = try launchResolver.resolve(
                    appID: appID,
                    route: route,
                    parameters: message.payload.userInfo ?? [:],
                    source: .notification
                )
                var payload = target.context.bridgePayload
                payload["webbridgekitOfflineMode"] = target.offlineMode.rawValue
                payload["webbridgekitPageURL"] = target.pageURL.absoluteString
                let params = WebBrowserParams(
                    displayMode: message.payload.targetMode == "modal" ? .modal : .immersive,
                    hideNavigationBar: message.payload.targetMode != "modal",
                    hideStatusBar: message.payload.targetMode != "modal",
                    hideTabBar: message.payload.targetMode != "modal",
                    payload: payload,
                    useManifestLoader: target.offlineMode == .strong,
                    preferCachedContent: target.offlineMode == .partial
                )
                WebBrowserManager.shared.openBrowser(url: target.loaderURL, params: params, from: self)
            } catch {
                showAlert(title: L10n.tr("message.detail.open_app_failed"), message: error.localizedDescription)
            }
            return
        }

        if let result = ManifestStore.shared.getManifestByAppId(appID), let url = URL(string: result.key) {
            WebBrowserManager.shared.openBrowser(
                url: url,
                params: WebBrowserParams(payload: message.payload.userInfo),
                from: self
            )
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.tr("common.ok"), style: .default))
        present(alert, animated: true)
    }
}

extension MessageDetailViewController: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript("document.body.scrollHeight") { [weak self] result, _ in
            guard let self, let height = (result as? NSNumber)?.doubleValue else { return }
            self.markdownHeightConstraint?.update(offset: ceil(height) + 16)
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.navigationType == .linkActivated {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            if url.scheme == "http" || url.scheme == "https" {
                WebBrowserManager.shared.openBrowser(
                    url: url,
                    params: WebBrowserParams(payload: self.message.payload.userInfo),
                    from: self
                )
                decisionHandler(.cancel)
                return
            }
        }
        decisionHandler(.allow)
    }
}
