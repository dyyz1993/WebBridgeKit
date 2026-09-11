import SnapKit
import UIKit
import WebBridgeKit

final class MessageMediaCardView: UIView {
    private let contentStack = UIStackView()
    private let imageView = UIImageView()
    private let placeholderIcon = UIImageView()
    private let statusLabel = UILabel()
    private let placeholderStack = UIStackView()
    private let saveButton = UIButton(type: .system)
    private var loadTask: URLSessionDataTask?
    private var imageHeightConstraint: Constraint?

    /// The host owns the Photo Library permission and persistence flow; this
    /// card only exposes deliberate user gestures for the already-downloaded
    /// attachment.
    var onSaveRequested: ((UIImage) -> Void)?
    var onSaveMenuRequested: ((UIImage) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        loadTask?.cancel()
    }

    func load(source: String) {
        accessibilityValue = "loading"
        statusLabel.text = L10n.tr("message.detail.media_loading")
        statusLabel.textColor = ThemeTokens.Color.textSecondary
        placeholderIcon.image = LucideIcon.image.templateImage(pointSize: ThemeTokens.Icons.Sizes.lg)
        placeholderIcon.tintColor = ThemeTokens.Color.info
        placeholderStack.isHidden = false
        saveButton.isHidden = true

        guard let url = URL(string: source) else {
            showFailure()
            return
        }

        loadTask = URLSession.shared.dataTask(with: url) { [weak self] data, response, _ in
            let statusCode = (response as? HTTPURLResponse)?.statusCode
            let image = data.flatMap(UIImage.init(data:))
            DispatchQueue.main.async {
                guard let self else { return }
                guard let image, statusCode.map({ (200...299).contains($0) }) != false else {
                    self.showFailure()
                    return
                }
                self.imageView.image = image
                self.imageHeightConstraint?.update(offset: 168)
                self.placeholderStack.isHidden = true
                self.saveButton.isHidden = false
                self.accessibilityValue = "loaded"
            }
        }
        loadTask?.resume()
    }

    private func setupUI() {
        backgroundColor = ThemeTokens.Color.surface
        layer.cornerRadius = ThemeTokens.CornerRadius.md
        clipsToBounds = true
        accessibilityIdentifier = "message.detail.media"
        accessibilityLabel = L10n.tr("message.detail.media_attachment")

        imageView.backgroundColor = ThemeTokens.Color.backgroundSecondary
        imageView.contentMode = .scaleAspectFill
        imageView.isUserInteractionEnabled = true
        imageView.accessibilityIdentifier = "message.detail.mediaImage"

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleImageLongPress(_:)))
        longPress.minimumPressDuration = WebBridgeKitConfiguration.Gesture.longPressMinimumDuration
        imageView.addGestureRecognizer(longPress)

        placeholderIcon.contentMode = .scaleAspectFit

        statusLabel.font = ThemeTokens.Typography.metadata
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 2

        // Icon + caption live in one stack centered on the tinted image area
        // (not the whole card): the failure caption previously straddled the
        // gray/white boundary because it was centered against the card.
        placeholderStack.axis = .vertical
        placeholderStack.alignment = .center
        placeholderStack.spacing = ThemeTokens.Spacing.sm
        placeholderStack.isUserInteractionEnabled = false
        placeholderStack.addArrangedSubview(placeholderIcon)
        placeholderStack.addArrangedSubview(statusLabel)

        saveButton.setTitle(L10n.tr("message.detail.media.save"), for: .normal)
        saveButton.setImage(LucideIcon.download.templateImage(pointSize: 16, weight: .semibold), for: .normal)
        // This action sits directly below user-provided images. Keep it in
        // Drel's primary color instead of the lavender accent so it remains
        // legible on blue/purple attachments in both appearances.
        saveButton.tintColor = ThemeTokens.Color.onPrimary
        saveButton.setTitleColor(ThemeTokens.Color.onPrimary, for: .normal)
        saveButton.backgroundColor = ThemeTokens.Color.primary
        saveButton.layer.cornerRadius = ThemeTokens.CornerRadius.sm
        saveButton.layer.masksToBounds = true
        saveButton.titleLabel?.font = ThemeTokens.Typography.metadata
        saveButton.accessibilityIdentifier = "message.detail.media.save"
        saveButton.accessibilityLabel = L10n.tr("message.detail.media.save_accessibility")
        saveButton.addTarget(self, action: #selector(handleSaveButton), for: .touchUpInside)

        // A vertical stack drives the card height: hidden arranged subviews
        // leave the layout on their own, so the save strip needs no height
        // toggling (a collapsed 0pt button constraint tripped the design
        // lint's button-height rule and kept reserving space when hidden).
        contentStack.axis = .vertical
        contentStack.spacing = 0
        contentStack.alignment = .fill

        addSubview(imageView)
        addSubview(placeholderStack)
        addSubview(contentStack)
        contentStack.addArrangedSubview(saveButton)

        imageView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            imageHeightConstraint = make.height.equalTo(168).constraint
        }
        placeholderStack.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(imageView)
            make.leading.greaterThanOrEqualToSuperview().inset(ThemeTokens.Spacing.lg)
            make.trailing.lessThanOrEqualToSuperview().inset(ThemeTokens.Spacing.lg)
        }
        contentStack.snp.makeConstraints { make in
            make.top.equalTo(imageView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
        saveButton.snp.makeConstraints { make in
            make.height.equalTo(44)
        }
        saveButton.isHidden = true
    }

    private func showFailure() {
        imageView.image = nil
        imageHeightConstraint?.update(offset: 96)
        saveButton.isHidden = true
        placeholderIcon.image = LucideIcon.warning.templateImage(pointSize: ThemeTokens.Icons.Sizes.lg)
        placeholderIcon.tintColor = ThemeTokens.Color.error
        statusLabel.text = L10n.tr("message.detail.media_unavailable")
        statusLabel.textColor = ThemeTokens.Color.error
        placeholderStack.isHidden = false
        accessibilityValue = "failed"
    }

    @objc private func handleSaveButton() {
        guard let image = imageView.image else { return }
        onSaveRequested?(image)
    }

    @objc private func handleImageLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, let image = imageView.image else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onSaveMenuRequested?(image)
    }
}
