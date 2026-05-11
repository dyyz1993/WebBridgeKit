//
//  HUDService.swift
//  WebBridgeKit
//
//  Lightweight HUD service replacing SVProgressHUD with native UIKit.
//

import UIKit

public final class HUDService {

    public static let shared = HUDService()

    private var hudWindow: UIWindow?
    private var hudView: HUDContainerView?
    private var dismissWorkItem: DispatchWorkItem?

    private let animationDuration: TimeInterval = 0.25
    private let successDisplayDuration: TimeInterval = 1.5

    private init() {}

    // MARK: - Public API

    public func show(_ status: String? = nil) {
        DispatchQueue.main.async { [self] in
            showHUD(status: status, style: .`default`)
        }
    }

    public func showProgress(_ progress: Float, status: String? = nil) {
        DispatchQueue.main.async { [self] in
            showHUD(status: status, style: .progress(progress))
        }
    }

    public func showSuccess(withStatus status: String) {
        DispatchQueue.main.async { [self] in
            showHUD(status: status, style: .success)
            scheduleAutoDismiss(delay: successDisplayDuration)
        }
    }

    public func showError(withStatus status: String) {
        DispatchQueue.main.async { [self] in
            showHUD(status: status, style: .error)
            scheduleAutoDismiss(delay: successDisplayDuration)
        }
    }

    public func showInfo(withStatus status: String) {
        DispatchQueue.main.async { [self] in
            showHUD(status: status, style: .info)
            scheduleAutoDismiss(delay: successDisplayDuration)
        }
    }

    public func setStatus(_ status: String) {
        DispatchQueue.main.async { [self] in
            hudView?.updateStatus(status)
        }
    }

    public func dismiss() {
        DispatchQueue.main.async { [self] in
            dismissAnimated()
        }
    }

    public func dismiss(withDelay delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [self] in
            dismissAnimated()
        }
    }

    // MARK: - Private

    enum HUDStyle {
        case `default`
        case progress(Float)
        case success
        case error
        case info
    }

    private func showHUD(status: String?, style: HUDStyle) {
        cancelAutoDismiss()

        let window = makeWindow()
        self.hudWindow = window

        let container = HUDContainerView()
        container.configure(status: status, style: style)
        self.hudView = container

        window.addSubview(container)
        container.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            container.centerXAnchor.constraint(equalTo: window.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: window.centerYAnchor),
            container.leadingAnchor.constraint(greaterThanOrEqualTo: window.leadingAnchor, constant: 20),
            container.trailingAnchor.constraint(lessThanOrEqualTo: window.trailingAnchor, constant: -20)
        ])

        window.alpha = 0
        UIView.animate(withDuration: animationDuration) {
            window.alpha = 1
        }
    }

    private func dismissAnimated() {
        guard let window = hudWindow else { return }

        cancelAutoDismiss()

        UIView.animate(
            withDuration: animationDuration,
            animations: {
                window.alpha = 0
            },
            completion: { _ in
                window.isHidden = true
                self.hudView = nil
                self.hudWindow = nil
            }
        )
    }

    private func scheduleAutoDismiss(delay: TimeInterval) {
        cancelAutoDismiss()
        let item = DispatchWorkItem { [weak self] in
            self?.dismissAnimated()
        }
        dismissWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func cancelAutoDismiss() {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
    }

    private func makeWindow() -> UIWindow {
        if let existing = hudWindow {
            existing.isHidden = false
            existing.alpha = 1
            return existing
        }

        let windowScene: UIWindowScene?
        if #available(iOS 15.0, *) {
            windowScene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }
                ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        } else {
            windowScene = UIApplication.shared.windows.first?.windowScene
        }

        let window: UIWindow
        if let scene = windowScene {
            window = UIWindow(windowScene: scene)
        } else {
            window = UIWindow(frame: UIScreen.main.bounds)
        }

        window.windowLevel = .statusBar + 1
        window.backgroundColor = .clear
        window.isHidden = false
        return window
    }
}

// MARK: - HUDContainerView

private final class HUDContainerView: UIView {

    private let backgroundView = UIView()
    private let contentView = UIView()
    private let iconView = UIImageView()
    private let statusLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .default)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        backgroundView.backgroundColor = UIColor(white: 0, alpha: 0.8)
        backgroundView.layer.cornerRadius = ThemeTokens.CornerRadius.lg
        backgroundView.layer.masksToBounds = true

        contentView.backgroundColor = .clear

        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = .white

        statusLabel.font = .systemFont(ofSize: 14, weight: .medium)
        statusLabel.textColor = .white
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0

        progressView.progressTintColor = ThemeTokens.Color.primary
        progressView.trackTintColor = UIColor.white.withAlphaComponent(0.3)
        progressView.layer.cornerRadius = ThemeTokens.CornerRadius.xs
        progressView.clipsToBounds = true

        let stack = UIStackView(arrangedSubviews: [iconView, progressView, statusLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = ThemeTokens.Spacing.sm

        backgroundView.addSubview(stack)
        addSubview(backgroundView)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        progressView.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),

            stack.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: backgroundView.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: backgroundView.bottomAnchor, constant: -20),

            iconView.widthAnchor.constraint(equalToConstant: 36),
            iconView.heightAnchor.constraint(equalToConstant: 36),

            progressView.widthAnchor.constraint(equalToConstant: 120),
            progressView.heightAnchor.constraint(equalToConstant: 4)
        ])
    }

    func configure(status: String?, style: HUDService.HUDStyle) {
        switch style {
        case .`default`:
            iconView.image = nil
            configureActivityIndicator()
            progressView.isHidden = true
        case .progress(let progress):
            iconView.image = nil
            removeActivityIndicator()
            progressView.isHidden = false
            progressView.setProgress(progress, animated: true)
        case .success:
            iconView.image = LucideIcon.success.image()
            removeActivityIndicator()
            progressView.isHidden = true
        case .error:
            iconView.image = LucideIcon.error.image()
            removeActivityIndicator()
            progressView.isHidden = true
        case .info:
            iconView.image = LucideIcon.info.image()
            removeActivityIndicator()
            progressView.isHidden = true
        }

        statusLabel.text = status
        statusLabel.isHidden = (status == nil)
    }

    func updateStatus(_ status: String) {
        statusLabel.text = status
        statusLabel.isHidden = status.isEmpty
    }

    private var activityIndicator: UIActivityIndicatorView?

    private func configureActivityIndicator() {
        removeActivityIndicator()
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        indicator.startAnimating()
        indicator.translatesAutoresizingMaskIntoConstraints = false

        insertSubview(indicator, aboveSubview: backgroundView)

        indicator.centerXAnchor.constraint(equalTo: iconView.centerXAnchor).isActive = true
        indicator.centerYAnchor.constraint(equalTo: iconView.centerYAnchor).isActive = true
        indicator.widthAnchor.constraint(equalToConstant: 36).isActive = true
        indicator.heightAnchor.constraint(equalToConstant: 36).isActive = true

        iconView.isHidden = true
        activityIndicator = indicator
    }

    private func removeActivityIndicator() {
        activityIndicator?.stopAnimating()
        activityIndicator?.removeFromSuperview()
        activityIndicator = nil
        iconView.isHidden = false
    }
}
