import UIKit
import SnapKit
import RxSwift
import RxCocoa
import WebBridgeKit

private enum MainSection: Int, CaseIterable {
    case pushToken = 0
    case appGrid = 1
    case quickActions = 2
}

class MainViewController: BaseViewController<MainViewModel> {

    private var collectionView: UICollectionView!

    private let emptyStateView: EmptyStateView = {
        let view = EmptyStateView()
        view.isHidden = true
        return view
    }()

    private let loadingView = LoadingView()

    private lazy var trashButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setImage(LucideIcon.trash.image(pointSize: 18, weight: .semibold), for: .normal)
        btn.tintColor = ThemeTokens.Colors.Light.textSecondary
        btn.addTarget(self, action: #selector(clearCacheTapped), for: .touchUpInside)
        return btn
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
        ("qrcode.viewfinder", L10n.tr("home.quick_action.scan"), UIColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 1.0)),
        ("doc.on.clipboard", L10n.tr("home.quick_action.paste"), UIColor(red: 1.0, green: 0.584, blue: 0.0, alpha: 1.0)),
        ("tray", L10n.tr("home.quick_action.inbox"), UIColor(red: 0.686, green: 0.322, blue: 0.871, alpha: 1.0))
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
                            self.showAlert(title: L10n.tr("home.command.success_title"), message: L10n.tr("home.command.not_found_message_format", appid))
                        }
                    case .url(let urlString):
                        if let url = URL(string: urlString) {
                            self.openURL(url)
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
        view.backgroundColor = ThemeColors.current.background
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
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(44)
        }
        commandBanner.alpha = 0
        commandBanner.transform = CGAffineTransform(translationX: 0, y: -44)

        let scanContainer: UIView = {
            let v = UIView()
            v.backgroundColor = .clear
            v.layer.borderWidth = 1.5
            v.layer.borderColor = UIColor(red: 0.776, green: 0.776, blue: 0.784, alpha: 1.0).cgColor
            v.layer.cornerRadius = 16
            v.clipsToBounds = true
            return v
        }()
        let scanIconView = UIImageView()
        scanIconView.image = LucideIcon.scan.image(pointSize: 18, weight: .semibold)
        scanIconView.tintColor = ThemeColors.current.primary
        scanIconView.contentMode = .scaleAspectFit
        scanContainer.addSubview(scanIconView)
        scanIconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(18)
        }
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(openScanner))
        scanContainer.addGestureRecognizer(tapGesture)
        scanContainer.snp.makeConstraints { make in
            make.width.height.equalTo(32)
        }
        let scanItem = UIBarButtonItem(customView: scanContainer)
        scanItem.accessibilityIdentifier = "main.scanButton"
        navigationItem.leftBarButtonItem = scanItem

        let storageItem = UIBarButtonItem(customView: trashButton)
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
            if sectionIndex == MainSection.pushToken.rawValue {
                return self.createPushTokenSection(environment: environment)
            } else if sectionIndex == MainSection.quickActions.rawValue {
                return self.createQuickActionsSection(environment: environment)
            } else {
                let gridSections = self.viewModel.historiesRelayValue.count
                return self.createAppGridSection(sectionIndex: sectionIndex, gridSections: gridSections, environment: environment)
            }
        }
    }

    private func createPushTokenSection(environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(90))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(90))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        group.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16)
        let section = NSCollectionLayoutSection(group: group)
        return section
    }

    private func createQuickActionsSection(environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.25), heightDimension: .absolute(76))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(76))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: 4)
        group.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16)
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0)
        return section
    }

    private func createAppGridSection(sectionIndex: Int, gridSections: Int, environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let containerWidth = environment.container.contentSize.width - 32
        let itemWidth = (containerWidth - 16) / 2
        let itemSize = NSCollectionLayoutSize(widthDimension: .absolute(itemWidth), heightDimension: .absolute(140))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(widthDimension: .absolute(itemWidth), heightDimension: .absolute(140))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        let rowSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(140))
        let row = NSCollectionLayoutGroup.horizontal(layoutSize: rowSize, subitem: group, count: 2)
        row.interItemSpacing = .fixed(16)
        row.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        let section = NSCollectionLayoutSection(group: row)
        section.interGroupSpacing = 16
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 0, bottom: 24, trailing: 0)

        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(36))
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

        let scanButtonTap = Driver<Void>.empty()

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
            .asDriver(onErrorJustReturn: "")
            .drive()
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

    @objc private func clearCacheTapped() {
        WebCacheManager.shared.clearAll()
        viewModel.refreshData()
    }

    private func handleQuickAction(index: Int) {
        switch index {
        case 0: openScanner()
        case 1: CommandHandler.shared.checkClipboardOnForeground()
        case 2:
            if let tabBarController = self.tabBarController {
                tabBarController.selectedIndex = 1
            }
        default: break
        }
    }
}

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
                header.titleLabel.text = sections[gridIndex].header.uppercased()
            }
            return header
        }
        return UICollectionReusableView()
    }
}

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
