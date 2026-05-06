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
        f.dateFormat = "MM-dd HH:mm"
        return f
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "发现"
        setupUI()
        loadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadData()
    }

    private func setupUI() {
        view.backgroundColor = .systemGroupedBackground
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always

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
            title: "发现应用",
            description: "缓存的应用会显示在这里",
            actionTitle: nil
        )

        addLongPressGesture()
    }

    private func createSectionLayout(section: Int) -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(0.5),
            heightDimension: .estimated(140)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(140)
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
        newSections.append(DiscoverSection(title: "最近使用", items: recentItems))

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
        newSections.append(DiscoverSection(title: "已缓存应用", items: cachedItems))

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
            case .persistent: return "持久化"
            case .cached: return "离线可用"
            case .needsUpdate: return "需更新"
            case .notCached: return "未缓存"
            }
        }

        var color: UIColor {
            switch self {
            case .persistent: return .systemBlue
            case .cached: return .systemGreen
            case .needsUpdate: return .systemOrange
            case .notCached: return .systemGray
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
            message: "缓存: \(item.cacheSize)\(item.lastAccessed.map { " · 访问: \($0)" } ?? "")",
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: "打开", style: .default) { [weak self] _ in
            self?.openURL(item.url)
        })
        alert.addAction(UIAlertAction(title: "删除缓存", style: .destructive) { [weak self] _ in
            self?.deleteCache(for: item)
        })
        alert.addAction(UIAlertAction(title: "分享", style: .default) { [weak self] _ in
            self?.shareURL(item.url)
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
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
        label.textColor = .label
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(8)
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
        view.layer.cornerRadius = 16
        return view
    }()

    private let iconContainer: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        view.layer.cornerRadius = 20
        return view
    }()

    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.tintColor = .systemBlue
        return iv
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .label
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
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
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 1
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
            make.top.equalToSuperview().offset(16)
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
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 0, left: 6, bottom: 0, right: 6))
        }

        detailLabel.snp.makeConstraints { make in
            make.top.equalTo(badgeView.snp.bottom).offset(4)
            make.leading.equalToSuperview().offset(8)
            make.trailing.equalToSuperview().offset(-8)
            make.bottom.equalToSuperview().offset(-8)
        }
    }

    func configure(with item: DiscoverItem) {
        nameLabel.text = item.name
        badgeLabel.text = item.cacheStatus.displayText
        badgeLabel.textColor = item.cacheStatus.color
        badgeView.backgroundColor = item.cacheStatus.color.withAlphaComponent(0.1)

        var detailParts: [String] = []
        if !item.cacheSize.isEmpty && item.cacheSize != "0 bytes" {
            detailParts.append(item.cacheSize)
        }
        if let accessed = item.lastAccessed {
            detailParts.append(accessed)
        }
        detailLabel.text = detailParts.isEmpty ? nil : detailParts.joined(separator: " · ")

        if let url = URL(string: item.url), let host = url.host {
            let iconImage: UIImage
            if host.contains("github") {
                iconImage = UIImage(systemName: "chevron.left.forwardslash.chevron.right")!
                iconContainer.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.1)
                iconImageView.tintColor = .systemPurple
            } else if host.contains("doc") || host.contains("docs") {
                iconImage = UIImage(systemName: "doc.text.fill")!
                iconContainer.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.1)
                iconImageView.tintColor = .systemOrange
            } else {
                iconImage = UIImage(systemName: "globe")!
                iconContainer.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
                iconImageView.tintColor = .systemBlue
            }
            iconImageView.image = iconImage
        }
    }
}
