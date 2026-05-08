//
//  DiscoverViewController.swift
//  SuperApp
//
//  Created on 2026-05-07.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa
import WebBridgeKit

class DiscoverViewController: UIViewController {

    private let disposeBag = DisposeBag()

    private var collectionView: UICollectionView!

    private let emptyStateView: EmptyStateView = {
        let view = EmptyStateView()
        view.isHidden = true
        return view
    }()

    private var sections: [DiscoverSection] = []

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM-dd"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.tr("discover.title")
        setupUI()
        loadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadData()
    }

    private func setupUI() {
        view.backgroundColor = ThemeColors.current.background
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: LucideIcon.refresh.image(pointSize: 20),
            style: .plain,
            target: self,
            action: #selector(refreshData)
        )

        let layout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, _ in
            guard let self = self else { return nil }
            return self.createSectionLayout(section: sectionIndex)
        }

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(DiscoverAppCell.self, forCellWithReuseIdentifier: DiscoverAppCell.identifier)
        collectionView.register(DiscoverSectionHeader.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: DiscoverSectionHeader.identifier)

        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        collectionView.refreshControl = refreshControl

        view.addSubview(collectionView)
        view.addSubview(emptyStateView)

        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        emptyStateView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(40)
        }

        emptyStateView.configure(
            icon: "compass",
            title: L10n.tr("discover.empty.title"),
            description: L10n.tr("discover.empty.description"),
            actionTitle: nil
        )

        addLongPressGesture()
    }

    private func createSectionLayout(section: Int) -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(0.5),
            heightDimension: .estimated(150)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(150)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item, item])

        let sectionLayout = NSCollectionLayoutSection(group: group)
        sectionLayout.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)

        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(40)
        )
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        sectionLayout.boundarySupplementaryItems = [header]

        return sectionLayout
    }

    @objc private func refreshData() {
        loadData()
    }

    private func loadData() {
        buildSections()
        collectionView.reloadData()
        collectionView.refreshControl?.endRefreshing()
        emptyStateView.isHidden = !sections.allSatisfy { $0.items.isEmpty }
    }

    private func buildSections() {
        var newSections: [DiscoverSection] = []

        let histories = WebPageHistoryManager.shared.getAllHistories()
        let recentItems = histories.prefix(6).map { history -> DiscoverItem in
            let cacheStatus = DiscoverItem.CacheStatus(from: history)
            let cacheSize = ByteCountFormatter.string(fromByteCount: history.cachedSize, countStyle: .file)
            let lastAccessed = Self.dateFormatter.string(from: history.lastVisitDate)
            return DiscoverItem(
                name: history.title ?? history.url,
                url: history.url,
                cacheStatus: cacheStatus,
                cacheSize: cacheSize,
                lastAccessed: lastAccessed
            )
        }
        newSections.append(DiscoverSection(title: L10n.tr("discover.section.recent"), items: recentItems))

        var cachedItems: [DiscoverItem] = []
        let keys = ManifestStore.shared.getAllPageKeys()
        for key in keys {
            if let manifest = ManifestStore.shared.getManifest(for: key) {
                let name = manifest.name ?? key
                let cacheStatus: DiscoverItem.CacheStatus = manifest.persistent == true ? .persistent : .cached
                let entryURL = manifest.resources.values.first ?? key
                let cacheSize = ByteCountFormatter.string(
                    fromByteCount: PersistentManifestLoader.shared.getCacheSize(for: key),
                    countStyle: .file
                )
                let lastAccessed = manifest.lastUpdated.map { Self.dateFormatter.string(from: $0) }
                cachedItems.append(DiscoverItem(
                    name: name,
                    url: entryURL,
                    cacheStatus: cacheStatus,
                    cacheSize: cacheSize,
                    lastAccessed: lastAccessed
                ))
            }
        }
        newSections.append(DiscoverSection(title: L10n.tr("discover.section.cached"), items: cachedItems))

        sections = newSections
    }

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        WebBrowserManager.shared.openBrowser(
            url: url,
            params: WebBrowserParams(displayMode: .normal),
            from: navigationController
        )
    }
}

// MARK: - Models

struct DiscoverSection {
    let title: String
    let items: [DiscoverItem]
}

struct DiscoverItem {
    let name: String
    let url: String
    let cacheStatus: CacheStatus
    var cacheSize: String
    var lastAccessed: String?

    enum CacheStatus {
        case persistent
        case cached
        case needsUpdate
        case notCached

        var displayText: String {
            switch self {
            case .persistent: return L10n.tr("discover.badge.persistent")
            case .cached: return L10n.tr("discover.badge.offline")
            case .needsUpdate: return L10n.tr("discover.badge.needs_update")
            case .notCached: return L10n.tr("discover.badge.not_cached")
            }
        }

        var color: UIColor {
            switch self {
            case .persistent: return ThemeTokens.Colors.Light.primary
            case .cached: return ThemeTokens.Colors.Light.success
            case .needsUpdate: return ThemeTokens.Colors.Light.warning
            case .notCached: return ThemeColors.current.secondary
            }
        }

        init(from history: WebPageHistory) {
            if history.isCached {
                self = .cached
            } else {
                self = .notCached
            }
        }
    }
}

// MARK: - UICollectionViewDataSource

extension DiscoverViewController: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return sections.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return sections[section].items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: DiscoverAppCell.identifier,
            for: indexPath
        ) as! DiscoverAppCell
        let item = sections[indexPath.section].items[indexPath.item]
        cell.configure(with: item)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            let header = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: DiscoverSectionHeader.identifier,
                for: indexPath
            ) as! DiscoverSectionHeader
            header.configure(title: sections[indexPath.section].title)
            return header
        }
        return UICollectionReusableView()
    }
}

// MARK: - UICollectionViewDelegate

extension DiscoverViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = sections[indexPath.section].items[indexPath.item]
        openURL(item.url)
    }
}

// MARK: - Long Press

extension DiscoverViewController {
    func addLongPressGesture() {
        let gesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        collectionView.addGestureRecognizer(gesture)
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        let point = gesture.location(in: collectionView)
        guard let indexPath = collectionView.indexPathForItem(at: point) else { return }
        let item = sections[indexPath.section].items[indexPath.item]
        showItemActionSheet(item: item)
    }

    private func showItemActionSheet(item: DiscoverItem) {
        let alert = UIAlertController(
            title: item.name,
            message: "\(L10n.tr("discover.action_sheet.cache")): \(item.cacheSize)\(item.lastAccessed.map { " · \(L10n.tr("discover.action_sheet.visit")): \($0)" } ?? "")",
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: L10n.tr("discover.action_sheet.open"), style: .default) { [weak self] _ in
            self?.openURL(item.url)
        })
        alert.addAction(UIAlertAction(title: L10n.tr("discover.action_sheet.delete_cache"), style: .destructive) { [weak self] _ in
            self?.deleteCache(for: item)
        })
        alert.addAction(UIAlertAction(title: L10n.tr("discover.action_sheet.share"), style: .default) { [weak self] _ in
            self?.shareURL(item.url)
        })
        alert.addAction(UIAlertAction(title: L10n.tr("common.cancel"), style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        present(alert, animated: true)
    }

    private func deleteCache(for item: DiscoverItem) {
        if let url = URL(string: item.url) {
            PersistentManifestLoader.shared.clearCache(for: url)
        }
        ManifestStore.shared.removeManifest(for: item.name)
        loadData()
    }

    private func shareURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }
        present(activityVC, animated: true)
    }
}

// MARK: - DiscoverSectionHeader

class DiscoverSectionHeader: UICollectionReusableView {

    static let identifier = "DiscoverSectionHeader"

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .bold)
        label.textColor = ThemeColors.current.text
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.centerY.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String) {
        titleLabel.text = title
    }
}

// MARK: - DiscoverAppCell

class DiscoverAppCell: UICollectionViewCell {

    static let identifier = "DiscoverAppCell"

    private let cardView: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeColors.current.cardBackground
        view.layer.cornerRadius = ThemeTokens.CornerRadius.xl
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 12
        view.layer.shadowOpacity = 0.08
        return view
    }()

    private let iconContainer: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 22
        view.clipsToBounds = true
        return view
    }()

    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.tintColor = ThemeColors.current.primary
        return iv
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .bold)
        label.textColor = ThemeColors.current.text
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.textAlignment = .center
        return label
    }()

    private let badgeView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 4
        return view
    }()

    private let badgeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 9, weight: .bold)
        label.textAlignment = .center
        return label
    }()

    private let detailLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 10, weight: .regular)
        label.textColor = ThemeColors.current.textSecondary
        label.textAlignment = .center
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        contentView.backgroundColor = .clear
        contentView.addSubview(cardView)
        cardView.addSubview(iconContainer)
        iconContainer.addSubview(iconImageView)
        cardView.addSubview(nameLabel)
        cardView.addSubview(badgeView)
        badgeView.addSubview(badgeLabel)
        cardView.addSubview(detailLabel)

        cardView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(4)
        }

        iconContainer.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(14)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(44)
        }

        iconImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(24)
        }

        nameLabel.snp.makeConstraints { make in
            make.top.equalTo(iconContainer.snp.bottom).offset(10)
            make.leading.equalToSuperview().offset(12)
            make.trailing.equalToSuperview().offset(-12)
        }

        badgeView.snp.makeConstraints { make in
            make.top.equalTo(nameLabel.snp.bottom).offset(8)
            make.centerX.equalToSuperview()
            make.height.equalTo(16)
        }

        badgeLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6))
        }

        detailLabel.snp.makeConstraints { make in
            make.top.equalTo(badgeView.snp.bottom).offset(4)
            make.leading.equalToSuperview().offset(8)
            make.trailing.equalToSuperview().offset(-8)
            make.bottom.equalToSuperview().offset(-14)
        }
    }

    func configure(with item: DiscoverItem) {
        nameLabel.text = item.name
        badgeLabel.text = item.cacheStatus.displayText
        badgeLabel.textColor = item.cacheStatus.color
        badgeView.backgroundColor = item.cacheStatus.color.withAlphaComponent(ThemeTokens.Opacity.badge)

        let colors = Self.gradientColor(for: item.name)
        iconContainer.backgroundColor = colors.bg
        iconImageView.tintColor = colors.tint
        iconImageView.image = LucideIcon.globe.image(pointSize: 20)

        var detailParts: [String] = []
        if !item.cacheSize.isEmpty && item.cacheSize != "0 bytes" {
            detailParts.append(item.cacheSize)
        }
        if let accessed = item.lastAccessed {
            detailParts.append(accessed)
        }
        detailLabel.text = detailParts.isEmpty ? nil : detailParts.joined(separator: " · ")
    }

    private static func gradientColor(for name: String) -> (bg: UIColor, tint: UIColor) {
        let hash = abs(name.hashValue)
        let colors: [(UIColor, UIColor)] = [
            (UIColor(red: 0, green: 0.478, blue: 1, alpha: 0.1), UIColor(red: 0, green: 0.478, blue: 1, alpha: 1)),
            (UIColor(red: 0.686, green: 0.322, blue: 0.878, alpha: 0.1), UIColor(red: 0.686, green: 0.322, blue: 0.878, alpha: 1)),
            (UIColor(red: 1, green: 0.584, blue: 0, alpha: 0.1), UIColor(red: 1, green: 0.584, blue: 0, alpha: 1)),
            (UIColor(red: 0.204, green: 0.78, blue: 0.349, alpha: 0.1), UIColor(red: 0.204, green: 0.78, blue: 0.349, alpha: 1)),
            (UIColor(red: 1, green: 0.231, blue: 0.188, alpha: 0.1), UIColor(red: 1, green: 0.231, blue: 0.188, alpha: 1)),
            (UIColor(red: 0.353, green: 0.784, blue: 1, alpha: 0.1), UIColor(red: 0.353, green: 0.784, blue: 1, alpha: 1)),
        ]
        return colors[hash % colors.count]
    }
}
