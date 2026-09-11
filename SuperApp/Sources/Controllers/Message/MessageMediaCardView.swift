import SnapKit
import UIKit
import WebBridgeKit

final class MessageMediaCardView: UIView {
    private let imageView = UIImageView()
    private let placeholderIcon = UIImageView()
    private let statusLabel = UILabel()
    private let placeholderStack = UIStackView()
    private let saveButton = UIButton(type: .system)
    private var loadTask: URLSessionDataTask?
    private var heightConstraint: Constraint?
    private var saveButtonHeightConstraint: Constraint?

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
        statusLabel.isHidden = false
        placeholderIcon.image = LucideIcon.image.templateImage(pointSize: ThemeTokens.Icons.Sizes.lg)
        placeholderIcon.tintColor = ThemeTokens.Color.info
        placeholderStack.isHidden = false
        setSaveButtonVisible(false)

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
                self.heightConstraint?.update(offset: 168)
                self.placeholderStack.isHidden = true
                self.setSaveButtonVisible(true)
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
        // gray/white boundary because it was centered against the card while
        // the hidden save button kept reserving 44pt of body below.
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
        saveButton.isHidden = true
        saveButton.accessibilityIdentifier = "message.detail.media.save"
        saveButton.accessibilityLabel = L10n.tr("message.detail.media.save_accessibility")
        saveButton.addTarget(self, action: #selector(handleSaveButton), for: .touchUpInside)

        addSubview(imageView)
        addSubview(placeholderStack)
        addSubview(saveButton)

        imageView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            heightConstraint = make.height.equalTo(168).constraint
        }
        placeholderStack.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(imageView)
            make.leading.greaterThanOrEqualToSuperview().inset(ThemeTokens.Spacing.lg)
            make.trailing.lessThanOrEqualToSuperview().inset(ThemeTokens.Spacing.lg)
        }
        saveButton.snp.makeConstraints { make in
            make.top.equalTo(imageView.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
            saveButtonHeightConstraint = make.height.equalTo(0).constraint
        }
        setSaveButtonVisible(false)
    }

    /// The save action collapses to zero height instead of hiding in place:
    /// a hidden-but-constrained button kept reserving a 44pt white band that
    /// showed through on the failure state.
    private func setSaveButtonVisible(_ visible: Bool) {
        saveButton.isHidden = !visible
        saveButtonHeightConstraint?.update(offset: visible ? 44 : 0)
    }

    private func showFailure() {
        imageView.image = nil
        heightConstraint?.update(offset: 96)
        setSaveButtonVisible(false)
        placeholderIcon.image = LucideIcon.warning.templateImage(pointSize: ThemeTokens.Icons.Sizes.lg)
        placeholderIcon.tintColor = ThemeTokens.Color.error
        statusLabel.text = L10n.tr("message.detail.media_unavailable")
        statusLabel.textColor = ThemeTokens.Color.error
        statusLabel.isHidden = false
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
