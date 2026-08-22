//
//  HTMLAppPermissionPromptPresenter.swift
//  WebBridgeKit
//

import SnapKit
import UIKit

public struct HTMLAppPermissionConsentRequest: Equatable, Sendable {
    public struct Application: Equatable, Sendable {
        public let id: String
        public let name: String

        public init(id: String, name: String) {
            self.id = id
            self.name = name
        }
    }

    public let application: Application
    public let requestID: String
    public let origin: String
    public let capability: HTMLAppCapability
    public let reason: String

    public init(
        application: Application,
        requestID: String,
        origin: String,
        capability: HTMLAppCapability,
        reason: String
    ) {
        self.application = application
        self.requestID = requestID
        self.origin = origin
        self.capability = capability
        self.reason = reason
    }
}

public protocol HTMLAppPermissionConsentPresenting: AnyObject {
    func requestConsent(
        _ request: HTMLAppPermissionConsentRequest,
        completion: @escaping (HTMLAppPermissionScope?) -> Void
    )

    func cancelConsent(appID: String, requestID: String)
}

public extension HTMLAppPermissionConsentPresenting {
    func cancelConsent(appID: String, requestID: String) {}
}

/// Default host UI for a managed PWA's first use of a protected Bridge action.
/// A nil scope means the user cancelled or denied the app-level request.
public final class HTMLAppPermissionPromptPresenter: HTMLAppPermissionConsentPresenting {
    public static let shared = HTMLAppPermissionPromptPresenter()

    private struct RequestIdentity: Equatable {
        let appID: String
        let origin: String
        let capability: HTMLAppCapability
    }

    private struct Subscriber {
        let requestID: String
        let completion: (HTMLAppPermissionScope?) -> Void
    }

    private struct PendingRequest {
        let identity: RequestIdentity
        let appName: String
        let reason: String
        var subscribers: [Subscriber]
    }

    private var activeRequest: PendingRequest?
    private var queuedRequests: [PendingRequest] = []
    private weak var activePrompt: HTMLAppPermissionPromptViewController?

    public init() {}

    public func requestConsent(
        _ request: HTMLAppPermissionConsentRequest,
        completion: @escaping (HTMLAppPermissionScope?) -> Void
    ) {
        DispatchQueue.main.async { [weak self] in
            self?.enqueue(request, completion: completion)
        }
    }

    public func cancelConsent(appID: String, requestID: String) {
        DispatchQueue.main.async { [weak self] in
            self?.cancel(appID: appID, requestID: requestID)
        }
    }

    private func enqueue(
        _ request: HTMLAppPermissionConsentRequest,
        completion: @escaping (HTMLAppPermissionScope?) -> Void
    ) {
        let identity = RequestIdentity(
            appID: request.application.id,
            origin: request.origin,
            capability: request.capability
        )
        let subscriber = Subscriber(requestID: request.requestID, completion: completion)

        if activeRequest?.identity == identity {
            activeRequest?.subscribers.append(subscriber)
            return
        }
        if let index = queuedRequests.firstIndex(where: { $0.identity == identity }) {
            queuedRequests[index].subscribers.append(subscriber)
            return
        }

        queuedRequests.append(PendingRequest(
            identity: identity,
            appName: request.application.name,
            reason: request.reason,
            subscribers: [subscriber]
        ))
        presentNextIfNeeded()
    }

    private func cancel(appID: String, requestID: String) {
        if var active = activeRequest, active.identity.appID == appID,
           let index = active.subscribers.firstIndex(where: { $0.requestID == requestID }) {
            let subscriber = active.subscribers.remove(at: index)
            activeRequest = active
            subscriber.completion(nil)
            if active.subscribers.isEmpty {
                if let activePrompt {
                    activePrompt.cancelFromHost()
                } else {
                    resolveActive(with: nil)
                }
            }
            return
        }

        for index in queuedRequests.indices {
            guard queuedRequests[index].identity.appID == appID,
                  let subscriberIndex = queuedRequests[index].subscribers.firstIndex(where: {
                      $0.requestID == requestID
                  }) else { continue }
            let subscriber = queuedRequests[index].subscribers.remove(at: subscriberIndex)
            if queuedRequests[index].subscribers.isEmpty {
                queuedRequests.remove(at: index)
            }
            subscriber.completion(nil)
            return
        }
    }

    private func presentNextIfNeeded() {
        guard activeRequest == nil, !queuedRequests.isEmpty else { return }
        activeRequest = queuedRequests.removeFirst()

        guard let activeRequest, let presenter = Self.topViewController() else {
            resolveActive(with: nil)
            return
        }

        let prompt = HTMLAppPermissionPromptViewController(
            appName: activeRequest.appName,
            origin: activeRequest.identity.origin,
            capability: activeRequest.identity.capability,
            reason: activeRequest.reason
        ) { [weak self] scope in
            self?.resolveActive(with: scope)
        }
        activePrompt = prompt
        prompt.modalPresentationStyle = .overFullScreen
        presenter.present(prompt, animated: false)
    }

    private func resolveActive(with scope: HTMLAppPermissionScope?) {
        guard let request = activeRequest else { return }
        activeRequest = nil
        activePrompt = nil
        request.subscribers.forEach { $0.completion(scope) }
        DispatchQueue.main.async { [weak self] in
            self?.presentNextIfNeeded()
        }
    }

    private static func topViewController() -> UIViewController? {
        let root = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
        return top(from: root)
    }

    private static func top(from root: UIViewController?) -> UIViewController? {
        if let presented = root?.presentedViewController { return top(from: presented) }
        if let navigation = root as? UINavigationController { return top(from: navigation.visibleViewController) }
        if let tabs = root as? UITabBarController { return top(from: tabs.selectedViewController) }
        return root
    }
}

private final class HTMLAppPermissionPromptViewController: UIViewController {
    private let appName: String
    private let origin: String
    private let capability: HTMLAppCapability
    private let reason: String
    private let completion: (HTMLAppPermissionScope?) -> Void

    private let dimmingControl = UIControl()
    private let sheetView = UIView()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let contentStack = UIStackView()
    private var hasResolved = false

    init(
        appName: String,
        origin: String,
        capability: HTMLAppCapability,
        reason: String,
        completion: @escaping (HTMLAppPermissionScope?) -> Void
    ) {
        self.appName = appName
        self.origin = origin
        self.capability = capability
        self.reason = reason
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        buildContent()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(systemConsentResult(_:)),
            name: .init("pwa.consent.systemResult"),
            object: nil
        )
    }

    @objc private func systemConsentResult(_ note: Notification) {
        let granted = note.userInfo?["granted"] as? Bool ?? false
        if granted {
            dismissPanel()
        } else if !hasResolved {
            showSettingsGuidance()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        sheetView.transform = CGAffineTransform(translationX: 0, y: sheetView.bounds.height)
        UIView.animate(
            withDuration: ThemeTokens.Animation.sheet.duration,
            delay: 0,
            usingSpringWithDamping: ThemeTokens.Animation.sheet.damping,
            initialSpringVelocity: ThemeTokens.Animation.sheet.velocity,
            options: [.curveEaseOut, .allowUserInteraction]
        ) {
            self.dimmingControl.alpha = 1
            self.sheetView.transform = .identity
        }
    }

    private func configureView() {
        view.backgroundColor = .clear
        view.accessibilityIdentifier = "pwa.permission.prompt"

        dimmingControl.backgroundColor = ThemeTokens.Color.scrim
        dimmingControl.alpha = 0
        dimmingControl.accessibilityIdentifier = "pwa.permission.dismissArea"
        dimmingControl.addTarget(self, action: #selector(cancel), for: .touchUpInside)
        view.addSubview(dimmingControl)
        dimmingControl.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        sheetView.backgroundColor = ThemeTokens.Color.surfaceElevated
        sheetView.layer.cornerRadius = ThemeTokens.CornerRadius.sheet
        sheetView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        sheetView.layer.shadowColor = UIColor.black.cgColor
        sheetView.layer.shadowOpacity = Float(ThemeTokens.Shadows.sheet.opacity)
        sheetView.layer.shadowRadius = ThemeTokens.Shadows.sheet.radius
        sheetView.layer.shadowOffset = CGSize(
            width: ThemeTokens.Shadows.sheet.offsetX,
            height: ThemeTokens.Shadows.sheet.offsetY
        )
        sheetView.accessibilityViewIsModal = true
        view.addSubview(sheetView)
        sheetView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.leading.equalToSuperview().offset(ThemeTokens.Spacing.md).priority(.high)
            make.trailing.equalToSuperview().inset(ThemeTokens.Spacing.md).priority(.high)
            make.width.lessThanOrEqualTo(520)
            make.top.greaterThanOrEqualTo(view.safeAreaLayoutGuide.snp.top).offset(ThemeTokens.Spacing.md)
            make.bottom.equalToSuperview()
            make.height.equalTo(620).priority(.high)
        }

        sheetView.addSubview(scrollView)
        scrollView.alwaysBounceVertical = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        scrollView.addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.width.equalTo(scrollView.frameLayoutGuide)
        }

        contentStack.axis = .vertical
        contentStack.spacing = ThemeTokens.Spacing.lg
        contentView.addSubview(contentStack)
        contentStack.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(ThemeTokens.Spacing.sm)
            make.leading.trailing.equalToSuperview().inset(ThemeTokens.Spacing.xl)
            make.bottom.equalToSuperview().inset(ThemeTokens.Spacing.screenBottom)
        }
    }

    private func buildContent() {
        contentStack.addArrangedSubview(makeGrabber())
        contentStack.addArrangedSubview(makeHeader())

        let titleLabel = UILabel()
        titleLabel.font = ThemeTokens.Typography.title2
        titleLabel.textColor = ThemeTokens.Color.text
        titleLabel.numberOfLines = 2
        titleLabel.lineBreakMode = .byCharWrapping
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        titleLabel.text = "允许使用\(capability.displayName)？"
        titleLabel.accessibilityIdentifier = "pwa.permission.title"
        contentStack.addArrangedSubview(titleLabel)

        contentStack.addArrangedSubview(makeReasonCard())
        contentStack.addArrangedSubview(makeScopeStack())
        contentStack.addArrangedSubview(makeSystemNotice())

        let sourceLabel = UILabel()
        sourceLabel.font = ThemeTokens.Typography.monospaceSmall
        sourceLabel.textColor = ThemeTokens.Color.textTertiary
        sourceLabel.numberOfLines = 2
        sourceLabel.textAlignment = .natural
        sourceLabel.lineBreakMode = .byWordWrapping
        // 通配样式（host/*）明示授权覆盖该域名下所有页面——与判定链的
        // origin 语义一致（scheme+host+port 精确匹配，path 不参与）
        let displayOrigin = origin.hasSuffix("/") ? origin + "*" : origin + "/*"
        sourceLabel.text = "来源 · \(displayOrigin)（该域名下所有页面）"
        sourceLabel.accessibilityIdentifier = "pwa.permission.origin"
        contentStack.addArrangedSubview(sourceLabel)

        let cancelButton = ThemeButton(type: .system)
        cancelButton.configure(title: "取消", style: .secondary)
        cancelButton.accessibilityIdentifier = "pwa.permission.cancel"
        cancelButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)
        cancelButton.snp.makeConstraints { make in
            make.height.equalTo(ThemeTokens.ComponentContract.Button.height)
        }
        contentStack.addArrangedSubview(cancelButton)
    }

    private func makeGrabber() -> UIView {
        let container = UIView()
        let grabber = UIView()
        grabber.backgroundColor = ThemeTokens.Color.backgroundTertiary
        grabber.layer.cornerRadius = ThemeTokens.CornerRadius.full
        container.addSubview(grabber)
        container.snp.makeConstraints { make in
            make.height.equalTo(ThemeTokens.Spacing.sm)
        }
        grabber.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(36)
            make.height.equalTo(5)
        }
        return container
    }

    private func makeHeader() -> UIView {
        let container = UIView()
        let iconView = UIView()
        iconView.backgroundColor = ThemeTokens.Color.primarySoft
        iconView.layer.cornerRadius = ThemeTokens.CornerRadius.lg

        let imageView = UIImageView(image: Self.icon(for: capability).templateImage(pointSize: 24, weight: .semibold))
        imageView.tintColor = ThemeTokens.Color.primary
        iconView.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(24)
        }

        let eyebrow = UILabel()
        eyebrow.font = ThemeTokens.Typography.caption2
        eyebrow.textColor = ThemeTokens.Color.primary
        eyebrow.text = "原生能力申请"

        let appLabel = UILabel()
        appLabel.font = ThemeTokens.Typography.cardTitle
        appLabel.textColor = ThemeTokens.Color.text
        appLabel.text = appName
        appLabel.lineBreakMode = .byTruncatingTail

        let labels = UIStackView(arrangedSubviews: [eyebrow, appLabel])
        labels.axis = .vertical
        labels.spacing = ThemeTokens.Spacing.xs

        container.addSubview(iconView)
        container.addSubview(labels)
        iconView.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.size.equalTo(52)
        }
        labels.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(ThemeTokens.Spacing.md)
            make.trailing.lessThanOrEqualToSuperview()
            make.centerY.equalTo(iconView)
        }
        return container
    }

    private func makeReasonCard() -> UIView {
        let container = UIView()
        container.backgroundColor = ThemeTokens.Color.backgroundSecondary
        container.layer.cornerRadius = ThemeTokens.CornerRadius.card

        let heading = UILabel()
        heading.font = ThemeTokens.Typography.caption2
        heading.textColor = ThemeTokens.Color.textSecondary
        heading.text = "用途说明"

        let body = UILabel()
        body.font = ThemeTokens.Typography.body
        body.textColor = ThemeTokens.Color.text
        body.numberOfLines = 0
        body.text = reason
        body.accessibilityIdentifier = "pwa.permission.reason"

        let stack = UIStackView(arrangedSubviews: [heading, body])
        stack.axis = .vertical
        stack.spacing = ThemeTokens.Spacing.sm
        container.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(ThemeTokens.Spacing.lg)
        }
        return container
    }

    private func makeScopeStack() -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = ThemeTokens.Spacing.sm

        let once = PermissionScopeButton(
            title: "仅这一次",
            subtitle: "完成当前操作后失效",
            recommended: false
        )
        once.accessibilityIdentifier = "pwa.permission.scope.once"
        once.addAction(UIAction { [weak self] _ in self?.resolve(.once) }, for: .touchUpInside)

        let session = PermissionScopeButton(
            title: "本次使用期间",
            subtitle: "关闭这个 PWA 后失效",
            recommended: true
        )
        session.accessibilityIdentifier = "pwa.permission.scope.appSession"
        session.addAction(UIAction { [weak self] _ in self?.resolve(.appSession) }, for: .touchUpInside)

        let always = PermissionScopeButton(
            title: "始终允许",
            subtitle: "可随时在应用设置中撤销",
            recommended: false
        )
        always.accessibilityIdentifier = "pwa.permission.scope.always"
        always.addAction(UIAction { [weak self] _ in self?.resolve(.always) }, for: .touchUpInside)

        [once, session, always].forEach { stack.addArrangedSubview($0) }
        return stack
    }

    private func makeSystemNotice() -> UIView {
        let container = UIView()
        let imageView = UIImageView(image: LucideIcon.info.templateImage(pointSize: 18, weight: .medium))
        imageView.tintColor = ThemeTokens.Color.info

        let label = UILabel()
        label.font = ThemeTokens.Typography.caption1
        label.textColor = ThemeTokens.Color.textSecondary
        label.numberOfLines = 0
        label.text = "允许后，iOS 仍可能显示系统权限确认。"
        label.accessibilityIdentifier = "pwa.permission.systemNotice"

        container.addSubview(imageView)
        container.addSubview(label)
        imageView.snp.makeConstraints { make in
            make.leading.top.equalToSuperview()
            make.size.equalTo(18)
        }
        label.snp.makeConstraints { make in
            make.leading.equalTo(imageView.snp.trailing).offset(ThemeTokens.Spacing.sm)
            make.trailing.top.bottom.equalToSuperview()
        }
        return container
    }

    @objc private func cancel() {
        resolve(nil)
    }

    func cancelFromHost() {
        resolve(nil)
    }

    private func resolve(_ scope: HTMLAppPermissionScope?) {
        guard !hasResolved else { return }
        hasResolved = true
        if scope == nil {
            // 取消：面板正常收起
            UIView.animate(
                withDuration: ThemeTokens.Animation.fast.duration,
                animations: {
                    self.dimmingControl.alpha = 0
                    self.sheetView.transform = CGAffineTransform(translationX: 0, y: self.sheetView.bounds.height)
                },
                completion: { _ in
                    self.dismiss(animated: false) {
                        self.completion(nil)
                    }
                }
            )
            return
        }
        // 选了范围：面板保持显示，iOS 系统弹窗会叠加在上面。
        // 系统授权结果由通知决定：成功 dismissPanel()，拒绝 showSettingsGuidance()。
        completion(scope)
    }

    /// 系统授权通过后面板正常收起
    public func dismissPanel() {
        UIView.animate(
            withDuration: ThemeTokens.Animation.fast.duration,
            animations: {
                self.dimmingControl.alpha = 0
                self.sheetView.transform = CGAffineTransform(translationX: 0, y: self.sheetView.bounds.height)
            },
            completion: { _ in
                self.dismiss(animated: false)
            }
        )
    }

    /// 系统授权拒绝后面板切引导态：提示去系统设置
    public func showSettingsGuidance() {
        // 隐藏三档按钮，显示引导文案+去设置按钮
        contentStack.arrangedSubviews.forEach { sub in
            if sub.accessibilityIdentifier == "pwa.permission.scopes" {
                sub.isHidden = true
            }
        }
        let guideLabel = UILabel()
        guideLabel.text = "iOS 系统已拒绝该权限。请前往系统设置开启后重试。"
        guideLabel.font = ThemeTokens.Typography.body
        guideLabel.textColor = ThemeTokens.Color.textSecondary
        guideLabel.numberOfLines = 0
        contentStack.addArrangedSubview(guideLabel)

        let settingsBtn = ThemeButton(type: .system)
        settingsBtn.setTitle("前往系统设置", for: .normal)
        settingsButtonConfigured(settingsBtn)
        contentStack.addArrangedSubview(settingsBtn)

    }

    private func settingsButtonConfigured(_ button: ThemeButton) {
        button.addTarget(self, action: #selector(openSystemSettings), for: .touchUpInside)
    }

    @objc private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private static func icon(for capability: HTMLAppCapability) -> LucideIcon {
        switch capability {
        case .biometrics: return .shield
        case .camera, .scan: return .camera
        case .clipboard, .contacts: return .clipboard
        case .fileExport, .fileImport: return .folder
        case .location: return .pin
        case .microphone: return .mic
        case .notification: return .bell
        case .photoLibrary: return .image
        case .share: return .share
        case .bluetooth, .deviceControl, .displayStatus, .motion: return .network
        @unknown default: return .shield
        }
    }
}

private final class PermissionScopeButton: UIButton {
    init(title: String, subtitle: String, recommended: Bool) {
        super.init(frame: .zero)

        backgroundColor = recommended ? ThemeTokens.Color.primarySoft : ThemeTokens.Color.surface
        layer.cornerRadius = ThemeTokens.CornerRadius.row
        layer.borderWidth = 1
        layer.borderColor = (recommended ? ThemeTokens.Color.primary : ThemeTokens.Color.border).cgColor
        accessibilityLabel = title
        accessibilityHint = subtitle

        let titleLabel = UILabel()
        titleLabel.font = ThemeTokens.Typography.rowTitle
        titleLabel.textColor = ThemeTokens.Color.text
        titleLabel.text = title

        let subtitleLabel = UILabel()
        subtitleLabel.font = ThemeTokens.Typography.caption1
        subtitleLabel.textColor = ThemeTokens.Color.textSecondary
        subtitleLabel.text = subtitle

        let labels = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        labels.axis = .vertical
        labels.spacing = ThemeTokens.Spacing.xs
        labels.isUserInteractionEnabled = false

        let iconView = UIImageView(image: LucideIcon.chevronRight.templateImage(pointSize: 16, weight: .semibold))
        iconView.tintColor = recommended ? ThemeTokens.Color.primary : ThemeTokens.Color.textTertiary

        addSubview(labels)
        addSubview(iconView)
        labels.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(ThemeTokens.Spacing.lg)
            make.top.bottom.equalToSuperview().inset(ThemeTokens.Spacing.md)
            make.trailing.lessThanOrEqualTo(iconView.snp.leading).offset(-ThemeTokens.Spacing.md)
        }
        iconView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(ThemeTokens.Spacing.lg)
            make.centerY.equalToSuperview()
            make.size.equalTo(16)
        }
        snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(64)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isHighlighted: Bool {
        didSet {
            alpha = isHighlighted ? ThemeTokens.Opacity.pressed : 1
        }
    }
}
