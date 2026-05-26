import UIKit
import SnapKit
import RxSwift
import RxCocoa
import WebBridgeKit

class DiscoverViewController: UIViewController {

    private let disposeBag = DisposeBag()

    private let scaffold = WBKScreenScaffold(style: .scrollable)
    private let searchField = WBKSearchField(placeholder: L10n.tr("discover.search.placeholder"))

    private var sectionViews: [UIView] = []
    private var emptyState: WBKEmptyState?

    var sections: [DiscoverSection] = []

    private var filteredSections: [DiscoverSection] = []

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
        setupUI()
        loadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadData()
    }

    private func setupUI() {
        view.backgroundColor = ThemeTokens.Color.background
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationItem.largeTitleDisplayMode = .never

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: LucideIcon.refresh.image(pointSize: 20),
            style: .plain,
            target: self,
            action: #selector(refreshData)
        )
        navigationItem.rightBarButtonItem?.accessibilityLabel = "刷新"

        view.addSubview(scaffold)
        scaffold.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        let titleSection = createTitleSection()
        scaffold.addSection(titleSection, spacing: ThemeTokens.Spacing.sm)

        scaffold.addSection(searchField, spacing: ThemeTokens.Spacing.lg)

        searchField.onTextChanged = { [weak self] text in
            self?.filterSections(query: text)
        }
        searchField.onSearchButtonTapped = { [weak self] in
            self?.view.endEditing(true)
        }
    }

    private func createTitleSection() -> UIView {
        let container = UIView()
        let titleLabel = UILabel()
        titleLabel.text = L10n.tr("tab.discover")
        titleLabel.font = ThemeTokens.Typography.screenTitle
        titleLabel.textColor = ThemeTokens.Color.text
        titleLabel.numberOfLines = 1

        container.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.bottom.equalToSuperview()
        }
        return container
    }

    @objc private func refreshData() {
        searchField.text = ""
        loadData()
    }

    func loadData() {
        Task { @MainActor in
            await buildSections()
            filteredSections = sections
            renderSections()
        }
    }

    private func filterSections(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            filteredSections = sections
        } else {
            filteredSections = sections.compactMap { section in
                let filtered = section.items.filter { item in
                    item.name.localizedCaseInsensitiveContains(trimmed)
                        || item.url.localizedCaseInsensitiveContains(trimmed)
                        || (item.descriptionText?.localizedCaseInsensitiveContains(trimmed) ?? false)
                }
                return filtered.isEmpty ? nil : DiscoverSection(title: section.title, items: filtered)
            }
        }
        renderSections()
    }

    private func renderSections() {
        scaffold.clearSections()
        sectionViews.removeAll()
        emptyState = nil

        let isEmpty = filteredSections.allSatisfy { $0.items.isEmpty }

        if isEmpty {
            let state: WBKEmptyState
            if sections.allSatisfy({ $0.items.isEmpty }) {
                state = WBKEmptyState(
                    icon: .compass,
                    title: L10n.tr("discover.empty.title"),
                    message: L10n.tr("discover.empty.description"),
                    actionTitle: L10n.tr("home.quick_action.scan"),
                    style: .default
                )
                state.onActionTapped = { [weak self] in
                    self?.openScanner()
                }
            } else {
                state = WBKEmptyState(
                    icon: .search,
                    title: L10n.tr("discover.search.no_result"),
                    message: L10n.tr("discover.search.no_result_desc"),
                    actionTitle: L10n.tr("discover.detail.clear"),
                    style: .default
                )
                state.onActionTapped = { [weak self] in
                    self?.searchField.text = ""
                    self?.filterSections(query: "")
                }
            }
            scaffold.addSection(state, spacing: ThemeTokens.Spacing.xxl)
            sectionViews.append(state)
            emptyState = state
            return
        }

        for (index, section) in filteredSections.enumerated() {
            let sectionView = buildSectionView(section: section, sectionIndex: index)
            let spacing: CGFloat = index == 0 ? ThemeTokens.Spacing.xs : ThemeTokens.Spacing.section
            scaffold.addSection(sectionView, spacing: spacing)
            sectionViews.append(sectionView)
        }
    }

    private func buildSectionView(section: DiscoverSection, sectionIndex: Int) -> UIView {
        let container = UIView()

        let header = WBKSectionHeader(title: section.title, style: .withCount)
        header.setCount(section.items.count)
        container.addSubview(header)
        header.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }

        let cardsStack = UIStackView()
        cardsStack.axis = .vertical
        cardsStack.spacing = ThemeTokens.Spacing.sm
        cardsStack.alignment = .fill

        for (itemIndex, item) in section.items.enumerated() {
            let card = createResourceCard(item: item, sectionIndex: sectionIndex, itemIndex: itemIndex)
            cardsStack.addArrangedSubview(card)
        }

        container.addSubview(cardsStack)
        cardsStack.snp.makeConstraints { make in
            make.top.equalTo(header.snp.bottom).offset(ThemeTokens.Spacing.sm)
            make.leading.trailing.bottom.equalToSuperview()
        }

        return container
    }

    private func createResourceCard(item: DiscoverItem, sectionIndex: Int, itemIndex: Int) -> WBKResourceCard {
        let icon = DiscoverViewController.iconForName(item.name)
        let card = WBKResourceCard(title: item.name, style: .compact)
        card.icon = icon.templateImage(pointSize: ThemeTokens.Icons.Sizes.md)

        var metaParts: [String] = []
        if !item.cacheSize.isEmpty {
            metaParts.append(item.cacheSize)
        }
        if let accessed = item.lastAccessed {
            metaParts.append(accessed)
        }
        card.metadata = metaParts.isEmpty ? nil : metaParts.joined(separator: " · ")

        if let desc = item.descriptionText, !desc.isEmpty {
            card.subtitle = desc
        }

        card.status = mapStatus(item.cacheStatus)

        card.trailingBadge = WBKStatusBadge(
            text: item.cacheStatus.displayText,
            style: mapBadgeStyle(item.cacheStatus)
        )

        card.onTap = { [weak self] in
            self?.openURL(item.url)
        }

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressOnCard(_:)))
        card.addGestureRecognizer(longPress)
        card.tag = sectionIndex * 1000 + itemIndex

        return card
    }

    private func mapStatus(_ cacheStatus: DiscoverItem.CacheStatus) -> WBKResourceCard.Status {
        switch cacheStatus {
        case .persistent: return .cached
        case .cached: return .cached
        case .needsUpdate: return .pending
        case .notCached: return .normal
        }
    }

    private func mapBadgeStyle(_ cacheStatus: DiscoverItem.CacheStatus) -> WBKStatusBadge.Style {
        switch cacheStatus {
        case .persistent: return .primary
        case .cached: return .success
        case .needsUpdate: return .warning
        case .notCached: return .default
        }
    }

    @objc private func handleLongPressOnCard(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        guard let cardView = gesture.view else { return }
        let tag = cardView.tag
        let sectionIndex = tag / 1000
        let itemIndex = tag % 1000
        guard sectionIndex < filteredSections.count,
              itemIndex < filteredSections[sectionIndex].items.count else { return }
        let item = filteredSections[sectionIndex].items[itemIndex]
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
            self?.confirmDeleteCache(for: item)
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

    private func confirmDeleteCache(for item: DiscoverItem) {
        let alert = UIAlertController(
            title: L10n.tr("discover.action_sheet.delete_cache"),
            message: "将清除「\(item.name)」的所有缓存数据，此操作不可撤销。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.tr("common.cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: L10n.tr("discover.action_sheet.delete_cache"), style: .destructive) { [weak self] _ in
            self?.deleteCache(for: item)
        })
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

    private func buildSections() async {
        var newSections: [DiscoverSection] = []

        let histories = (try? await WebPageHistoryManager.shared.getAllHistories()) ?? []
        let recentItems = histories.prefix(6).map { history -> DiscoverItem in
            let cacheStatus = DiscoverItem.CacheStatus(from: history)
            let cacheSize = ByteCountFormatter.string(fromByteCount: history.cachedSize, countStyle: .file)
            let lastAccessed = Self.relativeTimeString(for: history.lastVisitDate)
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
                let lastAccessed = manifest.lastUpdated.map { Self.relativeTimeString(for: $0) }
                cachedItems.append(DiscoverItem(
                    name: name,
                    url: entryURL,
                    cacheStatus: cacheStatus,
                    cacheSize: cacheSize,
                    lastAccessed: lastAccessed,
                    bundleID: "com.example.\(key.lowercased())",
                    version: "v1.0.0",
                    resourceCount: "\(manifest.resources.count) files",
                    cachedDate: manifest.lastUpdated.map { Self.dateFormatter.string(from: $0) },
                    expiresText: manifest.persistent == true ? L10n.tr("discover.detail.never") : L10n.tr("discover.detail.days_format", "7"),
                    visitCount: "-",
                    lastVisit: lastAccessed,
                    sourceText: L10n.tr("discover.detail.source_qr")
                ))
            }
        }
        newSections.append(DiscoverSection(title: L10n.tr("discover.section.cached"), items: cachedItems))

        let recommendedItems: [DiscoverItem] = [
            DiscoverItem(
                name: "Bridge 交互",
                url: "https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/bridge-interaction.html",
                cacheStatus: .cached,
                cacheSize: "1.8 MB",
                lastAccessed: nil,
                descriptionText: L10n.tr("discover.recommended.weather.desc")
            ),
            DiscoverItem(
                name: "Bridge 设备",
                url: "https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/bridge-device.html",
                cacheStatus: .cached,
                cacheSize: "0.9 MB",
                lastAccessed: nil,
                descriptionText: L10n.tr("discover.recommended.notes.desc")
            )
        ]
        newSections.append(DiscoverSection(title: L10n.tr("discover.section.recommended"), items: recommendedItems))

        sections = newSections
    }

    private static func relativeTimeString(for date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return L10n.tr("discover.time.just_now") }
        if interval < 3600 { return L10n.tr("discover.time.min_ago", "\(Int(interval / 60))") }
        if interval < 86400 { return L10n.tr("discover.time.hour_ago", "\(Int(interval / 3600))") }
        return L10n.tr("discover.time.days_ago", "\(Int(interval / 86400))")
    }

    func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        WebBrowserManager.shared.openBrowser(
            url: url,
            params: WebBrowserParams(displayMode: .normal),
            from: navigationController
        )
    }

    private func openScanner() {
        let config = QRScannerViewController.Configuration(
            showScanRegionOverlay: true,
            showCloseButton: true,
            tipText: L10n.tr("home.scanner.tip"),
            enableBase64Decoding: true,
            autoDismiss: false
        )
        let scannerVC = QRScannerViewController(configuration: config)
        scannerVC.scannerDidSuccess
            .subscribe(onNext: { [weak self, weak scannerVC] result in
                guard let self = self else { return }
                let url = URL(string: result)
                if let scanner = scannerVC, let nav = self.navigationController, nav.viewControllers.contains(scanner) {
                    CATransaction.begin()
                    CATransaction.setCompletionBlock {
                        if let url = url {
                            self.openURL(url.absoluteString)
                        }
                    }
                    nav.popViewController(animated: true)
                    CATransaction.commit()
                } else {
                    scannerVC?.dismiss(animated: true) {
                        if let url = url {
                            self.openURL(url.absoluteString)
                        }
                    }
                }
            })
            .disposed(by: disposeBag)
        navigationController?.pushViewController(scannerVC, animated: true)
    }
}
