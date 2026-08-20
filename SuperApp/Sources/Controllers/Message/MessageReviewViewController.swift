//
//  MessageReviewViewController.swift
//  SuperApp
//
//  Card-stack triage for unread messages: swipe right to mark read,
//  left to delete, up to skip. Mirrors Tinder-style review loops so a
//  whole inbox of unread messages can be processed with one gesture each.
//

import UIKit
import SnapKit
import WebBridgeKit

final class MessageReviewViewController: UIViewController {

    private let queue: [StoredMessage]
    private var cursor = 0
    private var readCount = 0
    private var deleteCount = 0
    private var skipCount = 0

    // MARK: UI

    private let progressLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.metadata
        label.textColor = ThemeTokens.Color.textSecondary
        label.textAlignment = .center
        label.accessibilityIdentifier = "review.progress"
        return label
    }()

    private let cardContainer = UIView()

    private let hintLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.tabLabel
        label.textColor = ThemeTokens.Color.textTertiary
        label.textAlignment = .center
        label.text = L10n.tr("review.tap_for_detail")
        return label
    }()

    private let markReadStamp: UILabel = stampLabel(L10n.tr("review.mark_read"), color: ThemeTokens.Color.success)
    private let deleteStamp: UILabel = stampLabel(L10n.tr("review.delete"), color: ThemeTokens.Color.error)
    private let skipStamp: UILabel = stampLabel(L10n.tr("review.skip"), color: ThemeTokens.Color.textSecondary)

    private static func stampLabel(_ text: String, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = "  \(text)  "
        label.font = ThemeTokens.Typography.sectionTitle
        label.textColor = color
        label.layer.borderColor = color.cgColor
        label.layer.borderWidth = 2
        label.layer.cornerRadius = 8
        label.layer.masksToBounds = true
        label.alpha = 0
        return label
    }

    /// Passive gesture legend — all operations are swipe-driven by design;
    /// the legend only teaches the vocabulary.
    private let gestureLegendLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.tabLabel
        label.textColor = ThemeTokens.Color.textSecondary
        label.textAlignment = .center
        label.text = "← \(L10n.tr("review.next"))    ↑ \(L10n.tr("review.skip"))    ↓ \(L10n.tr("review.delete"))"
        label.accessibilityIdentifier = "review.legend"
        return label
    }()

    private let doneView: UIView = {
        let view = UIView()
        view.isHidden = true
        return view
    }()

    private let doneTitleLabel: UILabel = {
        let label = UILabel()
        label.text = L10n.tr("review.done.title")
        label.font = ThemeTokens.Typography.compactTitle
        label.textColor = ThemeTokens.Color.text
        label.textAlignment = .center
        return label
    }()

    private let doneSummaryLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.metadata
        label.textColor = ThemeTokens.Color.textSecondary
        label.textAlignment = .center
        label.accessibilityIdentifier = "review.done.summary"
        return label
    }()

    private lazy var doneButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(L10n.tr("review.done.finish"), for: .normal)
        button.titleLabel?.font = ThemeTokens.Typography.rowTitle
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = ThemeTokens.Color.primary
        button.layer.cornerRadius = ThemeTokens.CornerRadius.pill
        button.accessibilityIdentifier = "review.done.finish"
        button.addTarget(self, action: #selector(finishTapped), for: .touchUpInside)
        return button
    }()

    // MARK: Init

    init(messages: [StoredMessage]) {
        self.queue = messages
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.tr("review.title")
        view.backgroundColor = ThemeTokens.Color.background
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(finishTapped)
        )

        view.addSubview(progressLabel)
        view.addSubview(cardContainer)
        view.addSubview(hintLabel)

        view.addSubview(gestureLegendLabel)

        progressLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(ThemeTokens.Spacing.sm)
            make.leading.trailing.equalToSuperview().inset(ThemeTokens.Spacing.md)
        }
        cardContainer.snp.makeConstraints { make in
            make.top.equalTo(progressLabel.snp.bottom).offset(ThemeTokens.Spacing.md)
            make.leading.trailing.equalToSuperview().inset(ThemeTokens.Spacing.xl)
            make.height.equalTo(360)
        }
        hintLabel.snp.makeConstraints { make in
            make.top.equalTo(cardContainer.snp.bottom).offset(ThemeTokens.Spacing.md)
            make.leading.trailing.equalToSuperview()
        }
        gestureLegendLabel.snp.makeConstraints { make in
            make.top.equalTo(hintLabel.snp.bottom).offset(ThemeTokens.Spacing.lg)
            make.leading.trailing.equalToSuperview().inset(ThemeTokens.Spacing.md)
        }

        setupDoneView()

        if queue.isEmpty {
            progressLabel.text = L10n.tr("review.empty")
            cardContainer.isHidden = true
            hintLabel.isHidden = true
            gestureLegendLabel.isHidden = true
            showDone()
        } else {
            renderCurrentCard()
            showCoachIfNeeded()
        }
    }

    private func setupDoneView() {
        view.addSubview(doneView)
        doneView.addSubview(doneTitleLabel)
        doneView.addSubview(doneSummaryLabel)
        doneView.addSubview(doneButton)
        doneView.snp.makeConstraints { make in
            make.center.equalTo(cardContainer)
            make.leading.trailing.equalToSuperview().inset(ThemeTokens.Spacing.xxl)
        }
        doneTitleLabel.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }
        doneSummaryLabel.snp.makeConstraints { make in
            make.top.equalTo(doneTitleLabel.snp.bottom).offset(ThemeTokens.Spacing.sm)
            make.leading.trailing.equalToSuperview()
        }
        doneButton.snp.makeConstraints { make in
            make.top.equalTo(doneSummaryLabel.snp.bottom).offset(ThemeTokens.Spacing.xl)
            make.centerX.equalToSuperview()
            make.width.equalTo(160)
            make.height.equalTo(44)
            make.bottom.equalToSuperview()
        }
    }

    // MARK: Card rendering

    private var currentCard: MessageReviewCardView?
    private var backgroundCard: MessageReviewCardView?

    /// Slightly smaller, shifted-up copy of the next message peeking behind
    /// the current card — the top sliver visible above the front card is the
    /// stack depth cue (the front card would otherwise fully cover it).
    private static let peekScale: CGFloat = 0.95
    private static let peekLift: CGFloat = 24

    private static func peekTransform(growth: CGFloat = 0) -> CGAffineTransform {
        let scale = peekScale + (1 - peekScale) * growth
        return CGAffineTransform(scaleX: scale, y: scale)
            .translatedBy(x: 0, y: -peekLift * (1 - growth * 0.6))
    }

    private func renderCurrentCard() {
        currentCard?.removeFromSuperview()
        backgroundCard?.removeFromSuperview()
        currentCard = nil
        backgroundCard = nil
        guard queue.indices.contains(cursor) else {
            showDone()
            return
        }
        if queue.indices.contains(cursor + 1) {
            let peek = MessageReviewCardView(message: queue[cursor + 1])
            peek.isUserInteractionEnabled = false
            cardContainer.addSubview(peek)
            peek.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            peek.transform = Self.peekTransform()
            backgroundCard = peek
        }
        let card = MessageReviewCardView(message: queue[cursor])
        card.accessibilityIdentifier = "review.card.current"
        cardContainer.addSubview(card)
        card.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        currentCard = card

        card.addStamp(markReadStamp, at: .topLeft)
        card.addStamp(deleteStamp, at: .topRight)
        card.addStamp(skipStamp, at: .bottomCenter)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleCardPan(_:)))
        card.addGestureRecognizer(pan)
        let tap = UITapGestureRecognizer(target: self, action: #selector(cardTapped))
        card.addGestureRecognizer(tap)

        progressLabel.text = "\(cursor + 1) / \(queue.count)"
    }

    // MARK: Gestures

    private enum SwipeDirection {
        /// Leftward = next (mark read + advance); up = skip; down = delete.
        /// Rightward is deliberately NOT a direction: the system edge-back
        /// gesture owns rightward navigation (exiting the review).
        case next, up, delete
    }

    @objc private func handleCardPan(_ gesture: UIPanGestureRecognizer) {
        guard let card = currentCard else { return }
        let translation = gesture.translation(in: view)
        switch gesture.state {
        case .changed:
            // Tinder feel: the card follows the finger AND rotates with the
            // horizontal offset, while the peeking card behind grows toward
            // full size as the top card is dragged away.
            let rotation = translation.x * 0.0012
            card.transform = CGAffineTransform(
                translationX: translation.x, y: translation.y
            ).rotated(by: rotation)
            markReadStamp.alpha = stampAlpha(for: -translation.x, threshold: 80)
            skipStamp.alpha = stampAlpha(for: -translation.y, threshold: 70)
            deleteStamp.alpha = stampAlpha(for: translation.y, threshold: 70)
            let growth = min(1, max(0, max(abs(translation.x), abs(translation.y)) / 160))
            backgroundCard?.transform = Self.peekTransform(growth: growth)
        case .ended, .cancelled, .failed:
            let velocity = gesture.velocity(in: view)
            let direction = resolveDirection(translation: translation, velocity: velocity)
            if let direction = direction {
                flyOff(card: card, direction: direction)
            } else {
                UIView.animate(
                    withDuration: ThemeTokens.Animation.modal.duration,
                    delay: 0,
                    usingSpringWithDamping: 0.8,
                    initialSpringVelocity: 0.4
                ) {
                    card.transform = .identity
                    self.markReadStamp.alpha = 0
                    self.deleteStamp.alpha = 0
                    self.skipStamp.alpha = 0
                    self.backgroundCard?.transform = Self.peekTransform()
                }
            }
        default:
            break
        }
    }

    private func stampAlpha(for distance: CGFloat, threshold: CGFloat) -> CGFloat {
        min(1, max(0, distance / threshold))
    }

    private func resolveDirection(translation: CGPoint, velocity: CGPoint) -> SwipeDirection? {
        let horizontalLeft = -translation.x > abs(translation.y)
            && (-velocity.x > 600 || -translation.x > 110)
        let verticalUp = -translation.y > abs(translation.x)
            && (-velocity.y > 600 || -translation.y > 100)
        let verticalDown = translation.y > abs(translation.x)
            && (velocity.y > 600 || translation.y > 100)
        if horizontalLeft {
            return .next
        }
        if verticalUp {
            return .up
        }
        if verticalDown {
            return .delete
        }
        return nil
    }

    private func flyOff(card: UIView, direction: SwipeDirection) {
        let rotation: CGFloat
        let exit: CGAffineTransform
        switch direction {
        case .next:
            rotation = -0.4
            exit = CGAffineTransform(
                translationX: -(view.bounds.width + card.bounds.width), y: -40
            ).rotated(by: rotation)
        case .up:
            rotation = 0.1
            exit = CGAffineTransform(
                translationX: 0, y: -(view.bounds.height + card.bounds.height)
            ).rotated(by: rotation)
        case .delete:
            rotation = 0.3
            exit = CGAffineTransform(
                translationX: 40, y: view.bounds.height + card.bounds.height
            ).rotated(by: rotation)
        }
        // Show the matching stamp during the exit.
        switch direction {
        case .next: markReadStamp.alpha = 1
        case .up: skipStamp.alpha = 1
        case .delete: deleteStamp.alpha = 1
        }
        UIView.animate(
            withDuration: ThemeTokens.Animation.normal.duration,
            delay: 0,
            options: [.curveEaseIn],
            animations: {
                card.transform = exit
                card.alpha = 0
                // The peeking card takes the stage as the top card leaves.
                self.backgroundCard?.transform = .identity
            },
            completion: { [weak self] _ in
                guard let self = self else { return }
                switch direction {
                case .next: self.commitRead()
                case .up: self.commitSkip()
                case .delete: self.commitDelete()
                }
            }
        )
    }

    // MARK: Actions

    private func commitRead() {
        let message = queue[cursor]
        Task {
            await MessageEngine.shared.markAsRead(id: message.id)
        }
        readCount += 1
        advance()
    }

    private func commitDelete() {
        let message = queue[cursor]
        Task {
            await MessageEngine.shared.deleteMessage(id: message.id)
        }
        deleteCount += 1
        advance()
    }

    private func commitSkip() {
        skipCount += 1
        advance()
    }

    private func advance() {
        cursor += 1
        if cursor < queue.count {
            renderCurrentCard()
        } else {
            currentCard?.removeFromSuperview()
            currentCard = nil
            showDone()
        }
    }

    private func showDone() {
        doneSummaryLabel.text = L10n.tr("review.done.summary", readCount, deleteCount, skipCount)
        doneView.isHidden = false
        cardContainer.isHidden = true
        hintLabel.isHidden = true
        gestureLegendLabel.isHidden = true
        progressLabel.text = ""
    }

    // MARK: - First-run coach

    private static let coachShownKey = "review.coach.shown"

    private func showCoachIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Self.coachShownKey) else { return }

        let dim = UIView()
        dim.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        dim.accessibilityIdentifier = "review.coach.dim"
        view.addSubview(dim)
        dim.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        let panel = UIView()
        panel.backgroundColor = ThemeTokens.Color.surface
        panel.layer.cornerRadius = ThemeTokens.CornerRadius.card
        dim.addSubview(panel)
        panel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(ThemeTokens.Spacing.xl)
        }

        let titleLabel = UILabel()
        titleLabel.text = L10n.tr("review.coach.title")
        titleLabel.font = ThemeTokens.Typography.compactTitle
        titleLabel.textColor = ThemeTokens.Color.text
        titleLabel.textAlignment = .center

        func hintRow(arrow: String, hint: String, color: UIColor) -> UIView {
            let arrowLabel = UILabel()
            arrowLabel.text = arrow
            arrowLabel.font = ThemeTokens.Typography.sectionTitle
            arrowLabel.textColor = color
            arrowLabel.setContentHuggingPriority(.required, for: .horizontal)
            let hintLabel = UILabel()
            hintLabel.text = hint
            hintLabel.font = ThemeTokens.Typography.subheadline
            hintLabel.textColor = ThemeTokens.Color.text
            let row = UIStackView(arrangedSubviews: [arrowLabel, hintLabel])
            row.axis = .horizontal
            row.spacing = ThemeTokens.Spacing.lg
            row.alignment = .center
            return row
        }

        let rows = UIStackView(arrangedSubviews: [
            hintRow(arrow: "←", hint: L10n.tr("review.coach.next.hint"), color: ThemeTokens.Color.success),
            hintRow(arrow: "↑", hint: L10n.tr("review.coach.skip.hint"), color: ThemeTokens.Color.textSecondary),
            hintRow(arrow: "↓", hint: L10n.tr("review.coach.delete.hint"), color: ThemeTokens.Color.error)
        ])
        rows.axis = .vertical
        rows.spacing = ThemeTokens.Spacing.md

        let backNote = UILabel()
        backNote.text = L10n.tr("review.coach.back")
        backNote.font = ThemeTokens.Typography.tabLabel
        backNote.textColor = ThemeTokens.Color.textTertiary
        backNote.textAlignment = .center
        backNote.numberOfLines = 0

        let startButton = UIButton(type: .system)
        startButton.setTitle(L10n.tr("review.coach.start"), for: .normal)
        startButton.setTitleColor(.white, for: .normal)
        startButton.titleLabel?.font = ThemeTokens.Typography.rowTitle
        startButton.backgroundColor = ThemeTokens.Color.primary
        startButton.layer.cornerRadius = ThemeTokens.CornerRadius.pill
        startButton.accessibilityIdentifier = "review.coach.start"
        startButton.snp.makeConstraints { make in
            make.height.equalTo(44)
        }

        let content = UIStackView(arrangedSubviews: [titleLabel, rows, backNote, startButton])
        content.axis = .vertical
        content.spacing = ThemeTokens.Spacing.lg
        panel.addSubview(content)
        content.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(ThemeTokens.Spacing.xl)
        }

        let dismiss = { [weak dim] in
            UserDefaults.standard.set(true, forKey: Self.coachShownKey)
            UIView.animate(
                withDuration: ThemeTokens.Animation.fast.duration,
                animations: { dim?.alpha = 0 },
                completion: { _ in dim?.removeFromSuperview() }
            )
        }
        startButton.addTarget(self, action: #selector(coachDismissed(_:)), for: .touchUpInside)
        coachDismissHandler = dismiss
        let tap = UITapGestureRecognizer(target: self, action: #selector(coachDismissed(_:)))
        dim.addGestureRecognizer(tap)
    }

    private var coachDismissHandler: (() -> Void)?

    @objc private func coachDismissed(_ sender: Any) {
        coachDismissHandler?()
        coachDismissHandler = nil
    }

    @objc private func cardTapped() {
        guard queue.indices.contains(cursor) else { return }
        let detail = MessageDetailViewController(message: queue[cursor], peerMessages: queue)
        navigationController?.pushViewController(detail, animated: true)
    }

    @objc private func finishTapped() {
        navigationController?.popViewController(animated: true)
    }
}

// MARK: - Card view

final class MessageReviewCardView: UIView {

    private let sourceLabel = UILabel()
    private let timeLabel = UILabel()
    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()
    private let badgeLabel = UILabel()

    init(message: StoredMessage) {
        super.init(frame: .zero)
        backgroundColor = ThemeTokens.Color.surface
        layer.cornerRadius = ThemeTokens.CornerRadius.card
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.12
        layer.shadowRadius = 12
        layer.shadowOffset = CGSize(width: 0, height: 6)

        sourceLabel.font = ThemeTokens.Typography.metadata
        sourceLabel.textColor = ThemeTokens.Color.textSecondary
        timeLabel.font = ThemeTokens.Typography.metadata
        timeLabel.textColor = ThemeTokens.Color.textTertiary
        timeLabel.text = DateFormatter.localizedString(from: message.receivedAt, dateStyle: .none, timeStyle: .short)

        let subtitle = message.payload.subtitle?.trimmingCharacters(in: .whitespaces)
        if let subtitle, !subtitle.isEmpty {
            sourceLabel.text = subtitle
        } else {
            sourceLabel.text = message.payload.channel.uppercased()
        }

        titleLabel.font = ThemeTokens.Typography.compactTitle
        titleLabel.textColor = ThemeTokens.Color.text
        titleLabel.numberOfLines = 2
        titleLabel.text = message.payload.title

        bodyLabel.font = ThemeTokens.Typography.subheadline
        bodyLabel.textColor = ThemeTokens.Color.textSecondary
        bodyLabel.numberOfLines = 5
        let rawBody = message.bodyType == "markdown"
            ? (message.payload.markdown ?? message.payload.body)
            : message.payload.body
        bodyLabel.text = rawBody
            .replacingOccurrences(of: "[#*_>`]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "[\\s]+", with: " ", options: .regularExpression)

        badgeLabel.font = ThemeTokens.Typography.caption
        badgeLabel.textAlignment = .center
        badgeLabel.layer.cornerRadius = ThemeTokens.CornerRadius.xs
        badgeLabel.clipsToBounds = true
        if message.payload.actionState == .pending {
            badgeLabel.text = "  \(L10n.tr("message.action.pending"))  "
            badgeLabel.textColor = ThemeTokens.Color.warning
            badgeLabel.backgroundColor = ThemeTokens.Color.warning.withAlphaComponent(0.1)
        } else {
            badgeLabel.isHidden = true
        }

        let header = UIStackView(arrangedSubviews: [sourceLabel, UIView(), timeLabel])
        header.axis = .horizontal

        let stack = UIStackView(arrangedSubviews: [header, badgeLabel, titleLabel, bodyLabel])
        stack.axis = .vertical
        stack.spacing = ThemeTokens.Spacing.sm
        addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(ThemeTokens.Spacing.lg)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    enum StampPosition {
        case topLeft, topRight, bottomCenter
    }

    func addStamp(_ stamp: UILabel, at position: StampPosition) {
        addSubview(stamp)
        stamp.snp.makeConstraints { make in
            switch position {
            case .topLeft:
                make.top.leading.equalToSuperview().inset(ThemeTokens.Spacing.lg)
            case .topRight:
                make.top.trailing.equalToSuperview().inset(ThemeTokens.Spacing.lg)
            case .bottomCenter:
                make.bottom.centerX.equalToSuperview().inset(ThemeTokens.Spacing.lg)
            }
        }
    }
}
