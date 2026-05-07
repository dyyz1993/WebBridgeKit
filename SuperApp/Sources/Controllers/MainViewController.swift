//
//  MainViewController.swift
//  SuperApp
//
//  Created on 2025-01-29.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa
import WebBridgeKit

private enum MainSection: Int, CaseIterable {
    case pushToken = 0
    case quickActions = 1
    case appGrid = 2
}

class MainViewController: BaseViewController<MainViewModel> {

    private var collectionView: UICollectionView!

    private let emptyStateView: EmptyStateView = {
        let view = EmptyStateView()
        view.isHidden = true
        return view
    }()

    private let scanButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        let image = UIImage(systemName: "qrcode.viewfinder", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = .label
        return button
    }()

    private let loadingView = LoadingView()

    private let storageLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .right
        return label
    }()

    private let pushTokenCardCellId = "PushTokenCardCell"
    private let quickActionCellId = "QuickActionCell"

    private var pushURL: String {
        if let activeURL = ServerConfigManager.shared.getActiveBaseURL() {
            let key = PushNotificationManager.shared.barkKey
                ?? UserDefaults.standard.string(forKey: "com.webbridgekit.bark.key") ?? ""
            return key.isEmpty ? activeURL : "\(activeURL)/\(key)"
        }
        let server = UserDefaults.standard.string(forKey: "com.webbridgekit.bark.server") ?? "https://api.day.app"
        let key = UserDefaults.standard.string(forKey: "com.webbridgekit.bark.key") ?? ""
        return key.isEmpty ? server : "\(server)/\(key)"
    }

    private var deviceToken: String {
        return PushNotificationManager.shared.deviceToken ?? L10n.tr("home.device_token.not_registered")
    }

    private var isTokenRegistered: Bool {
        return PushNotificationManager.shared.deviceToken != nil
    }

    private let quickActions: [(icon: String, title: String, color: UIColor)] = [
        ("qrcode.viewfinder", L10n.tr("home.quick_action.scan"), .systemBlue),
        ("doc.on.clipboard", L10n.tr("home.quick_action.paste"), .systemOrange),
        ("text.badge.star", L10n.tr("home.quick_action.token"), .systemPurple),
        ("ladybug", L10n.tr("home.quick_action.debug"), .systemGreen)
    ]

    private lazy var commandBanner: CommandBannerView = {
        let banner = CommandBannerView()
        banner.isHidden = true
        banner.onTap = { [weak self] in
            self?.executePendingCommand()
        }
        banner.onDismiss = { [weak self] in
            self?.hideCommandBanner()
        }
        return banner
    }()

    private var pendingCommandTitle: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        Log.debug("viewDidLoad called", category: .ui)
        title = L10n.tr("home.title")
        setupUI()
        setupGestures()
        setupNotifications()
        WebCacheManager.shared.performAutoCleanup()
    }

    private func setupNotifications() {
        NotificationCenter.default.rx.notification(.automationTestOpenURL)
            .compactMap { $0.userInfo?["url"] as? String }
            .compactMap { URL(string: $0) }
            .subscribe(onNext: { [weak self] url in
                Log.info("Automation trigger: opening \(url.absoluteString) natively", category: .ui)
                self?.openURL(url)
            })
            .disposed(by: rx)

        NotificationCenter.default.rx.notification(.historyDidUpdate)
            .subscribe(onNext: { [weak self] _ in
                Log.info("History updated notification received", category: .ui)
                self?.viewModel.refreshData()
            })
            .disposed(by: rx)
    }

    private func handleScannedResult(url: URL?, rawString: String?) {
        Log.debug("Handling scanned result - URL: \(url?.absoluteString ?? "nil"), Raw: \(rawString ?? "nil")", category: .ui)
        if let url = url {
            if url.scheme == "wb-app" {
                handleCustomProtocol(url)
                return
            }
            if url.pathExtension == "json" || url.absoluteString.contains("manifest") {
                loadAndCacheManifest(url)
            } else {
                openURL(url)
            }
            return
        }
        if let raw = rawString {
            if raw.starts(with: "wb-app://") {
                if let customUrl = URL(string: raw) {
                    handleCustomProtocol(customUrl)
                } else {
                    showAlert(title: L10n.tr("home.alert.protocol_error"), message: L10n.tr("home.alert.protocol_error_message", raw))
                }
            } else {
                showAlert(title: L10n.tr("home.alert.invalid_content"), message: L10n.tr("home.alert.invalid_content_message", raw))
            }
        }
    }

    private func handleCustomProtocol(_ url: URL) {
        Log.debug("Handling custom protocol: \(url.absoluteString)", category: .ui)
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        if url.host == "load" {
            if let targetUrlString = components.queryItems?.first(where: { $0.name == "url" })?.value,
               let targetUrl = URL(string: targetUrlString) {
                handleScannedResult(url: targetUrl, rawString: targetUrlString)
            }
        } else if url.host == "open" {
            if let targetUrlString = components.queryItems?.first(where: { $0.name == "url" })?.value,
               let targetUrl = URL(string: targetUrlString) {
                openURL(targetUrl)
            }
        }
    }

    private func loadAndCacheManifest(_ url: URL) {
        loadingView.startLoading(message: L10n.tr("home.manifest.loading"))
        Task {
            do {
                let manifest = try await PersistentManifestLoader.shared.fetchManifest(from: url)
                await MainActor.run {
                    self.loadingView.stopLoading()
                    self.showAlert(title: L10n.tr("home.manifest.success_title"), message: L10n.tr("home.manifest.success_message_format", manifest.name ?? L10n.tr("common.unknown")))
                    self.viewModel.refreshData()
                }
            } catch {
                await MainActor.run {
                    self.loadingView.stopLoading()
                    Log.error("Failed to load manifest: \(error)", category: .ui)
                    self.openURL(url)
                }
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Log.debug("viewWillAppear - refreshing data", category: .ui)
        viewModel.refreshData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Log.debug("viewDidAppear", category: .ui)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            PassphraseManager.shared.checkClipboard(from: self)
            self.checkClipboardForCommand()
        }
    }

    private func checkClipboardForCommand() {
        guard let text = ClipboardMonitor.shared.readClipboard(),
              ClipboardMonitor.shared.looksLikeCommand(text) else {
            hideCommandBanner()
            return
        }

        Task {
            do {
                let payload = try await CommandParser.shared.parse(text)
                let title = payload.title ?? payload.appid
                await MainActor.run { [weak self] in
                    self?.pendingCommandTitle = title
                    self?.showCommandBanner(title: title)
                }
            } catch {
                hideCommandBanner()
            }
        }
    }

    private func showCommandBanner(title: String) {
        commandBanner.configure(title: title)
        commandBanner.isHidden = false
        UIView.animate(withDuration: 0.3) {
            self.commandBanner.alpha = 1
            self.commandBanner.transform = .identity
        }
    }

    private func hideCommandBanner() {
        pendingCommandTitle = nil
        guard !commandBanner.isHidden else { return }
        UIView.animate(withDuration: 0.25, animations: {
            self.commandBanner.alpha = 0
            self.commandBanner.transform = CGAffineTransform(translationX: 0, y: -self.commandBanner.bounds.height)
        }, completion: { _ in
            self.commandBanner.isHidden = true
        })
    }

    private func executePendingCommand() {
        let title = pendingCommandTitle
        hideCommandBanner()

        guard let text = ClipboardMonitor.shared.readClipboard(),
              ClipboardMonitor.shared.looksLikeCommand(text) else { return }
        UIPasteboard.general.string = ""

        Task {
            do {
                let payload = try await CommandParser.shared.parse(text)
                let route = CommandRouter.shared.route(payload)
                await MainActor.run {
                    switch route {
                    case .cachedApp(let appid):
                        if let urlStr = payload.url, let url = URL(string: urlStr) {
                            WebBrowserManager.shared.openBrowser(url: url)
                        } else {
                            showAlert(title: L10n.tr("home.command.success_title"), message: L10n.tr("home.command.not_found_message_format", appid))
                        }
                    case .url(let urlString):
                        if let url = URL(string: urlString) {
                            openURL(url)
                        }
                    case .deeplink(let urlString):
                        if let url = URL(string: urlString) {
                            UIApplication.shared.open(url)
                        }
                    case .none:
                        break
                    @unknown default:
                        break
                    }
                }
            } catch {
                Log.warning("Command parse failed: \(error)", category: .general)
            }
        }
    }

    private func setupUI() {
        view.backgroundColor = UIColor.systemGroupedBackground
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always

        let layout = createCompositionalLayout()
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 20, right: 0)
        collectionView.register(URLGridCell.self, forCellWithReuseIdentifier: URLGridCell.identifier)
        collectionView.register(PushTokenCardCell.self, forCellWithReuseIdentifier: pushTokenCardCellId)
        collectionView.register(QuickActionCell.self, forCellWithReuseIdentifier: quickActionCellId)
        collectionView.register(SectionHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: SectionHeaderView.identifier)
        collectionView.showsVerticalScrollIndicator = false
        collectionView.dataSource = self
        collectionView.delegate = self

        let topBackground = UIView()
        topBackground.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.05)
        view.insertSubview(topBackground, at: 0)
        topBackground.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
            make.height.equalTo(300)
        }

        view.addSubview(collectionView)
        view.addSubview(emptyStateView)
        view.addSubview(loadingView)

        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        collectionView.accessibilityIdentifier = "MainCollectionView"

        emptyStateView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        loadingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        view.addSubview(commandBanner)
        commandBanner.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(44)
        }
        commandBanner.alpha = 0
        commandBanner.transform = CGAffineTransform(translationX: 0, y: -44)

        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        let scanImage = LucideIcon.scan.image(pointSize: 18, weight: .semibold)
        let scanItem = UIBarButtonItem(image: scanImage, style: .plain, target: self, action: #selector(openScanner))
        scanItem.accessibilityIdentifier = "main.scanButton"
        navigationItem.leftBarButtonItem = scanItem

        let storageItem = UIBarButtonItem(customView: storageLabel)
        navigationItem.rightBarButtonItems = [storageItem]

        emptyStateView.configure(
            icon: "square.grid.2x2.fill",
            title: L10n.tr("home.empty.title"),
            description: L10n.tr("home.empty.description"),
            actionTitle: nil
        )
    }

    private func createCompositionalLayout() -> UICollectionViewCompositionalLayout {
        return UICollectionViewCompositionalLayout { [weak self] sectionIndex, environment in
            guard let self = self else { return nil }
            let gridSections = self.viewModel.historiesRelayValue.count
            if sectionIndex == MainSection.pushToken.rawValue {
                return self.createPushTokenSection(environment: environment)
            } else if sectionIndex == MainSection.quickActions.rawValue {
                return self.createQuickActionsSection(environment: environment)
            } else {
                return self.createAppGridSection(sectionIndex: sectionIndex, gridSections: gridSections, environment: environment)
            }
        }
    }

    private func createPushTokenSection(environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(120))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(120))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        group.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 0, bottom: 0, trailing: 0)
        return section
    }

    private func createQuickActionsSection(environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.25), heightDimension: .absolute(80))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(80))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: 4)
        group.interItemSpacing = .fixed(8)
        group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 0, bottom: 12, trailing: 0)
        return section
    }

    private func createAppGridSection(sectionIndex: Int, gridSections: Int, environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let itemWidth = (environment.container.contentSize.width - 40 - 16) / 2
        let itemSize = NSCollectionLayoutSize(widthDimension: .absolute(itemWidth), heightDimension: .absolute(160))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(widthDimension: .absolute(itemWidth), heightDimension: .absolute(160))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        let rowSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(160))
        let row = NSCollectionLayoutGroup.horizontal(layoutSize: rowSize, subitem: group, count: 2)
        row.interItemSpacing = .fixed(16)
        row.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
        let section = NSCollectionLayoutSection(group: row)
        section.interGroupSpacing = 20
        section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 0, bottom: 30, trailing: 0)

        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(50))
        let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)
        section.boundarySupplementaryItems = [header]
        return section
    }

    @objc private func openScanner() {
        let config = QRScannerViewController.Configuration(
            showScanRegionOverlay: true,
            showCloseButton: true,
            tipText: L10n.tr("home.scanner.tip"),
            enableBase64Decoding: true,
            autoDismiss: true
        )
        let scannerVC = QRScannerViewController(configuration: config)
        scannerVC.scannerDidSuccess
            .subscribe(onNext: { [weak self] result in
                let url = URL(string: result)
                self?.handleScannedResult(url: url, rawString: result)
            })
            .disposed(by: rx)
        navigationController?.pushViewController(scannerVC, animated: true)
    }

    private func setupGestures() {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        collectionView.refreshControl = refreshControl
    }

    override func bindViewModel() {
        Log.debug("bindViewModel called", category: .ui)

        let refreshTrigger = Driver.merge(
            collectionView.refreshControl!.rx.controlEvent(.valueChanged).asDriver(onErrorJustReturn: ()),
            rx.methodInvoked(#selector(UIViewController.viewWillAppear(_:))).map { _ in () }.asDriver(onErrorJustReturn: ())
        )

        let itemSelect = collectionView.rx.itemSelected
            .do(onNext: { indexPath in
                Log.debug("Cell tapped at indexPath: \(indexPath)", category: .ui)
            })
            .asDriver(onErrorDriveWith: .empty())

        let scanButtonTap = scanButton.rx.tap
            .asDriver(onErrorDriveWith: .empty())

        let itemLongPressRelay = PublishRelay<IndexPath>()

        let longPressGesture = UILongPressGestureRecognizer()
        collectionView.addGestureRecognizer(longPressGesture)
        longPressGesture.rx.event
            .filter { $0.state == .began }
            .subscribe(onNext: { [weak self] gesture in
                guard let self = self else { return }
                let point = gesture.location(in: self.collectionView)
                if let indexPath = self.collectionView.indexPathForItem(at: point) {
                    if indexPath.section >= MainSection.appGrid.rawValue {
                        itemLongPressRelay.accept(indexPath)
                    }
                }
            })
            .disposed(by: rx)

        let input = MainViewModel.Input(
            refresh: refreshTrigger,
            itemSelect: itemSelect,
            itemLongPress: itemLongPressRelay.asDriver(onErrorJustReturn: IndexPath(item: 0, section: 0)),
            scanButtonTap: scanButtonTap
        )

        let output = viewModel.transform(input: input)

        output.histories
            .drive(onNext: { [weak self] sections in
                self?.updateCollectionView(sections: sections)
            })
            .disposed(by: rx)

        output.isEmpty
            .drive(onNext: { [weak self] (isEmpty: Bool) in
                guard let self = self else { return }
                if isEmpty {
                    self.view.bringSubviewToFront(self.emptyStateView)
                    self.emptyStateView.isHidden = false
                    self.collectionView.isHidden = true
                    self.collectionView.alpha = 0
                } else {
                    self.emptyStateView.isHidden = true
                    self.collectionView.isHidden = false
                    self.collectionView.alpha = 1
                    self.view.bringSubviewToFront(self.collectionView)
                }
            })
            .disposed(by: rx)

        output.openURL
            .drive(onNext: { [weak self] url in
                self?.openURL(url)
            })
            .disposed(by: rx)

        output.showActionSheet
            .drive(onNext: { [weak self] url in
                self?.showActionSheet(url: url)
            })
            .disposed(by: rx)

        output.showScanner
            .drive(onNext: { [weak self] in
                self?.openScanner()
            })
            .disposed(by: rx)

        output.loading
            .drive(onNext: { [weak self] (loading: Bool) in
                if !loading {
                    self?.collectionView.refreshControl?.endRefreshing()
                }
            })
            .disposed(by: rx)

        viewModel.totalStorageSizeRelay
            .asDriver()
            .drive(storageLabel.rx.text)
            .disposed(by: rx)
    }

    private func updateCollectionView(sections: [WebPageHistorySection]) {
        Log.debug("updateCollectionView called with \(sections.count) sections", category: .ui)
        DispatchQueue.main.async { [weak self] in
            self?.collectionView.reloadData()
        }
    }

    @objc private func refreshData() {
        Log.debug("refreshData (Pull-to-refresh) triggered", category: .ui)
    }

    private func openURL(_ url: URL) {
        Log.debug("openURL called: \(url.absoluteString)", category: .ui)
        if url.scheme == "wb-app" && url.host == "test-cases" {
            if let tabBarController = self.tabBarController {
                tabBarController.selectedIndex = 1
            }
            return
        }
        if UserDefaults.standard.bool(forKey: "EnableLastAppMemory") {
            UserDefaults.standard.set(url.absoluteString, forKey: "LastOpenedURL")
            UserDefaults.standard.synchronize()
        }
        WebBrowserManager.shared.openBrowser(
            url: url,
            params: WebBrowserParams(displayMode: .normal),
            from: navigationController
        )
    }

    private func showActionSheet(url: URL) {
        let history = viewModel.getHistory(url: url)
        let alert = UIAlertController(
            title: history?.title ?? url.host ?? url.absoluteString,
            message: """
                \(L10n.tr("home.action_sheet.domain")): \(url.host ?? L10n.tr("common.unknown"))
                \(L10n.tr("home.action_sheet.cache_size")): \(history?.formattedSize ?? "0 KB")
                \(L10n.tr("home.action_sheet.visit_count_format", "\(history?.visitCount ?? 0)"))
                """,
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: L10n.tr("home.action_sheet.open"), style: .default, handler: { [weak self] _ in
            self?.openURL(url)
        }))
        let isPinned = viewModel.isPinned(url: url)
        alert.addAction(UIAlertAction(title: isPinned ? L10n.tr("home.action_sheet.unpin") : L10n.tr("home.action_sheet.pin"), style: .default, handler: { [weak self] _ in
            self?.viewModel.togglePin(url: url)
            self?.viewModel.refreshData()
        }))
        alert.addAction(UIAlertAction(title: L10n.tr("home.action_sheet.favorite"), style: .default, handler: { [weak self] _ in
            self?.viewModel.addToFavorites(url: url)
            self?.showAlert(title: L10n.tr("common.success"), message: L10n.tr("home.action_sheet.favorited_message"))
            self?.viewModel.refreshData()
        }))
        alert.addAction(UIAlertAction(title: L10n.tr("home.action_sheet.clear_cache"), style: .destructive, handler: { [weak self] _ in
            self?.viewModel.clearCache(url: url)
            self?.viewModel.refreshData()
        }))
        alert.addAction(UIAlertAction(title: L10n.tr("common.cancel"), style: .cancel))
        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = self.view
            popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
            popoverController.permittedArrowDirections = []
        }
        present(alert, animated: true)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.tr("common.ok"), style: .default))
        present(alert, animated: true)
    }

    private func handleQuickAction(index: Int) {
        switch index {
        case 0: openScanner()
        case 1: CommandHandler.shared.checkClipboardOnForeground()
        case 2:
            let vc = TokenGenerateViewController(viewModel: TokenGenerateViewModel())
            navigationController?.pushViewController(vc, animated: true)
        case 3:
            let vc = NotificationDebugViewController()
            navigationController?.pushViewController(vc, animated: true)
        default: break
        }
    }
}

// MARK: - UICollectionViewDataSource

extension MainViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2 + viewModel.historiesRelayValue.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == MainSection.pushToken.rawValue { return 1 }
        if section == MainSection.quickActions.rawValue { return 1 }
        let sections = viewModel.historiesRelayValue
        let gridIndex = section - MainSection.appGrid.rawValue
        guard gridIndex >= 0 && gridIndex < sections.count else { return 0 }
        return sections[gridIndex].items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == MainSection.pushToken.rawValue {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: pushTokenCardCellId, for: indexPath) as! PushTokenCardCell
            cell.configure(serverURL: pushURL, deviceToken: deviceToken, isRegistered: isTokenRegistered)
            cell.onCopyTapped = { [weak self] in
                guard let self = self else { return }
                let token = PushNotificationManager.shared.deviceToken ?? ""
                let copyText = token.isEmpty ? self.pushURL : "\(self.pushURL)/\(token)"
                UIPasteboard.general.string = copyText
                self.showAlert(title: L10n.tr("home.token_card.copied_title"), message: L10n.tr("home.token_card.copied_message"))
            }
            cell.onRegisterTapped = { [weak self] in
                PushNotificationManager.shared.registerForPushNotifications()
                self?.showAlert(title: L10n.tr("home.token_card.registering_title"), message: L10n.tr("home.token_card.registering_message"))
            }
            return cell
        }
        if indexPath.section == MainSection.quickActions.rawValue {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: quickActionCellId, for: indexPath) as! QuickActionCell
            cell.configure(actions: quickActions)
            cell.onActionTapped = { [weak self] index in
                self?.handleQuickAction(index: index)
            }
            return cell
        }

        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: URLGridCell.identifier, for: indexPath) as! URLGridCell
        let sections = viewModel.historiesRelayValue
        let gridIndex = indexPath.section - MainSection.appGrid.rawValue
        guard gridIndex >= 0 && gridIndex < sections.count else { return cell }
        let history = sections[gridIndex].items[indexPath.item]
        cell.history = history
        cell.onPinToggle = { [weak self] in
            guard let self = self, let url = URL(string: history.url) else { return }
            self.viewModel.togglePin(url: url)
            self.viewModel.refreshData()
        }
        cell.onFavoriteToggle = { [weak self] in
            guard let self = self, let url = URL(string: history.url) else { return }
            self.viewModel.toggleFavorite(url: url)
            self.viewModel.refreshData()
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: SectionHeaderView.identifier, for: indexPath) as! SectionHeaderView
            let sections = viewModel.historiesRelayValue
            let gridIndex = indexPath.section - MainSection.appGrid.rawValue
            if gridIndex >= 0 && gridIndex < sections.count {
                header.titleLabel.text = sections[gridIndex].header
            }
            return header
        }
        return UICollectionReusableView()
    }
}

// MARK: - UICollectionViewDelegate

extension MainViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.section >= MainSection.appGrid.rawValue else { return }
        let sections = viewModel.historiesRelayValue
        let gridIndex = indexPath.section - MainSection.appGrid.rawValue
        guard gridIndex >= 0 && gridIndex < sections.count else { return }
        let history = sections[gridIndex].items[indexPath.item]
        if let url = URL(string: history.url) {
            openURL(url)
            viewModel.refreshData()
        }
    }
}

// MARK: - PushTokenCardCell

private class PushTokenCardCell: UICollectionViewCell {
    static let identifier = "PushTokenCardCell"

    private let gradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.colors = [
            UIColor.systemBlue.withAlphaComponent(0.8).cgColor,
            UIColor.systemPurple.withAlphaComponent(0.8).cgColor
        ]
        layer.startPoint = CGPoint(x: 0, y: 0)
        layer.endPoint = CGPoint(x: 1, y: 1)
        layer.cornerRadius = 16
        return layer
    }()

    private let containerView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 16
        view.layer.masksToBounds = true
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .white.withAlphaComponent(0.9)
        label.text = "Push Token"
        return label
    }()

    private let urlLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        label.textColor = .white.withAlphaComponent(0.85)
        label.numberOfLines = 2
        label.lineBreakMode = .byTruncatingMiddle
        return label
    }()

    private let tokenLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        label.textColor = .white.withAlphaComponent(0.7)
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingMiddle
        return label
    }()

    private let copyButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        button.setImage(UIImage(systemName: "doc.on.doc", withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        button.layer.cornerRadius = 16
        return button
    }()

    private let registerButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(L10n.tr("home.token_card.register"), for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        button.tintColor = .white
        button.backgroundColor = UIColor.white.withAlphaComponent(0.25)
        button.layer.cornerRadius = 14
        button.isHidden = true
        return button
    }()

    var onCopyTapped: (() -> Void)?
    var onRegisterTapped: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = containerView.bounds
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onCopyTapped = nil
        onRegisterTapped = nil
    }

    private func setupUI() {
        contentView.addSubview(containerView)
        containerView.layer.insertSublayer(gradientLayer, at: 0)
        containerView.addSubview(titleLabel)
        containerView.addSubview(urlLabel)
        containerView.addSubview(tokenLabel)
        containerView.addSubview(copyButton)
        containerView.addSubview(registerButton)

        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(4)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.left.equalToSuperview().offset(16)
        }

        urlLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.left.equalToSuperview().offset(16)
            make.right.equalTo(copyButton.snp.left).offset(-12)
        }

        tokenLabel.snp.makeConstraints { make in
            make.top.equalTo(urlLabel.snp.bottom).offset(4)
            make.left.equalToSuperview().offset(16)
            make.right.equalTo(copyButton.snp.left).offset(-12)
            make.bottom.equalToSuperview().offset(-16)
        }

        copyButton.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(32)
        }

        registerButton.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.width.equalTo(56)
            make.height.equalTo(28)
        }

        copyButton.addTarget(self, action: #selector(copyTapped), for: .touchUpInside)
        registerButton.addTarget(self, action: #selector(registerTapped), for: .touchUpInside)
    }

    func configure(serverURL: String, deviceToken: String, isRegistered: Bool) {
        if isRegistered {
            urlLabel.text = serverURL
            tokenLabel.text = "Device: \(deviceToken.prefix(16))\(deviceToken.count > 16 ? "..." : "")"
            copyButton.isHidden = false
            registerButton.isHidden = true
        } else {
            urlLabel.text = serverURL
            tokenLabel.text = L10n.tr("home.token_card.not_registered")
            copyButton.isHidden = true
            registerButton.isHidden = false
        }
    }

    @objc private func copyTapped() {
        onCopyTapped?()
    }

    @objc private func registerTapped() {
        onRegisterTapped?()
    }
}

// MARK: - QuickActionCell

private class QuickActionCell: UICollectionViewCell {
    static let identifier = "QuickActionCell"

    private let stackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.distribution = .fillEqually
        sv.spacing = 8
        return sv
    }()

    var onActionTapped: ((Int) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onActionTapped = nil
    }

    private func setupUI() {
        contentView.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func configure(actions: [(icon: String, title: String, color: UIColor)]) {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, action) in actions.enumerated() {
            let btn = createActionButton(icon: action.icon, title: action.title, color: action.color)
            btn.tag = index
            btn.addTarget(self, action: #selector(actionTapped(_:)), for: .touchUpInside)
            stackView.addArrangedSubview(btn)
        }
    }

    private func createActionButton(icon: String, title: String, color: UIColor) -> UIButton {
        let button = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        button.setImage(UIImage(systemName: icon, withConfiguration: cfg), for: .normal)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        button.tintColor = color
        button.setTitleColor(color, for: .normal)
        button.backgroundColor = .secondarySystemGroupedBackground
        button.layer.cornerRadius = 12
        button.imageEdgeInsets = UIEdgeInsets(top: -12, left: 0, bottom: 0, right: 0)
        button.titleEdgeInsets = UIEdgeInsets(top: 20, left: -(button.titleLabel?.intrinsicContentSize.width ?? 0), bottom: 0, right: 0)
        return button
    }

    @objc private func actionTapped(_ sender: UIButton) {
        onActionTapped?(sender.tag)
    }
}

// MARK: - SectionHeaderView

class SectionHeaderView: UICollectionReusableView {
    static let identifier = "SectionHeader"

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        label.textColor = .label
        return label
    }()

    private let indicatorView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBlue
        view.layer.cornerRadius = 2
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(indicatorView)
        addSubview(titleLabel)
        indicatorView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(20)
            make.centerY.equalToSuperview()
            make.width.equalTo(4)
            make.height.equalTo(18)
        }
        titleLabel.snp.makeConstraints { make in
            make.left.equalTo(indicatorView.snp.right).offset(10)
            make.centerY.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - CommandBannerView

private class CommandBannerView: UIView {

    var onTap: (() -> Void)?
    var onDismiss: (() -> Void)?

    private let iconView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.tintColor = .systemBlue
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        iv.image = UIImage(systemName: "link.badge.plus", withConfiguration: config)
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = .label
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private let dismissButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        button.setImage(UIImage(systemName: "xmark.circle.fill", withConfiguration: config), for: .normal)
        button.tintColor = .secondaryLabel
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        layer.cornerRadius = 10
        clipsToBounds = true

        addSubview(iconView)
        addSubview(titleLabel)
        addSubview(dismissButton)

        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(20)
        }

        dismissButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-8)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(28)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(8)
            make.trailing.equalTo(dismissButton.snp.leading).offset(-4)
            make.centerY.equalToSuperview()
        }

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(bannerTapped))
        addGestureRecognizer(tapGesture)

        dismissButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
    }

    func configure(title: String) {
        titleLabel.text = L10n.tr("home.command.banner_format", title)
    }

    @objc private func bannerTapped() {
        onTap?()
    }

    @objc private func dismissTapped() {
        onDismiss?()
    }
}
