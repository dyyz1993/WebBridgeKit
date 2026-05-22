import UIKit
import SnapKit
import RxSwift
import RxCocoa
import WebBridgeKit

enum MainSection: Int, CaseIterable {
    case pushToken = 0
    case quickActions = 1
    case appGrid = 2
}

class MainViewController: BaseViewController<MainViewModel> {

    private let scaffold = WBKScreenScaffold(style: .scrollable)

    private let serverStatusBlock = ServerStatusBlock()
    private let actionTileGrid = ActionTileGrid()
    private let favoritesSection = ResourceListSection()
    private let recentSection = ResourceListSection()

    private let emptyStateView: EmptyStateView = {
        let view = EmptyStateView()
        view.isHidden = true
        return view
    }()

    let loadingView = LoadingView()

    private lazy var storageInfoButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.titleLabel?.font = ThemeTokens.Typography.metadata
        btn.setTitleColor(ThemeTokens.Color.textSecondary, for: .normal)
        btn.backgroundColor = ThemeTokens.Color.cardBackground
        btn.layer.cornerRadius = ThemeTokens.CornerRadius.card
        btn.clipsToBounds = true
        btn.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        btn.addTarget(self, action: #selector(clearCacheTapped), for: .touchUpInside)
        btn.accessibilityLabel = "清理缓存"
        btn.layer.borderWidth = 1
        btn.layer.borderColor = ThemeTokens.Color.border.cgColor
        btn.setTitle("0 MB", for: .normal)
        return btn
    }()

    var pushURL: String {
        if let activeURL = ServerConfigManager.shared.getActiveBaseURL() {
            let key = PushNotificationManager.shared.barkKey
                ?? UserDefaults.standard.string(forKey: "com.webbridgekit.bark.key") ?? ""
            return key.isEmpty ? activeURL : "\(activeURL)/\(key)"
        }
        let server = UserDefaults.standard.string(forKey: "com.webbridgekit.bark.server") ?? "https://wbk.shanbox.19930810.xyz:8443"
        let key = UserDefaults.standard.string(forKey: "com.webbridgekit.bark.key") ?? ""
        return key.isEmpty ? server : "\(server)/\(key)"
    }

    var deviceToken: String {
        return PushNotificationManager.shared.deviceToken ?? L10n.tr("home.device_token.not_registered")
    }

    var isTokenRegistered: Bool {
        return PushNotificationManager.shared.deviceToken != nil
    }

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

    private var currentSections: [WebPageHistorySection] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        Log.debug("viewDidLoad called", category: .ui)
        setupNavigationBar()
        setupScaffold()
        setupOverlays()
        setupGestures()
        setupNotifications()
        WebCacheManager.shared.performAutoCleanup()
    }

    private func setupNavigationBar() {
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.title = L10n.tr("tab.home")
        navigationController?.navigationBar.titleTextAttributes = [
            .foregroundColor: ThemeTokens.Color.text,
            .font: ThemeTokens.Typography.screenTitle
        ]

        let scanButton: UIButton = {
            let btn = UIButton(type: .system)
            btn.setImage(LucideIcon.qrCode.image(pointSize: 20, weight: .medium), for: .normal)
            btn.tintColor = ThemeTokens.Color.text
            btn.addTarget(self, action: #selector(openScanner), for: .touchUpInside)
            btn.accessibilityLabel = "扫描二维码"
            btn.snp.makeConstraints { make in
                make.width.height.equalTo(44)
            }
            return btn
        }()
        let scanItem = UIBarButtonItem(customView: scanButton)
        scanItem.accessibilityIdentifier = "main.scanButton"
        navigationItem.leftBarButtonItem = scanItem

        let storageItem = UIBarButtonItem(customView: storageInfoButton)
        storageItem.accessibilityIdentifier = "main.clearCacheButton"
        navigationItem.rightBarButtonItems = [storageItem]
    }

    private func setupScaffold() {
        view.addSubview(scaffold)
        scaffold.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        scaffold.addSection(serverStatusBlock, spacing: ThemeTokens.Spacing.section)
        scaffold.addSection(actionTileGrid, spacing: ThemeTokens.Spacing.section)
        scaffold.addSection(favoritesSection, spacing: ThemeTokens.Spacing.section)
        scaffold.addSection(recentSection)

        serverStatusBlock.configure(
            serverURL: pushURL,
            deviceToken: deviceToken,
            isRegistered: isTokenRegistered,
            onCopy: { [weak self] in
                UIPasteboard.general.string = self?.pushURL ?? ""
                HUDService.shared.showSuccess(withStatus: L10n.tr("home.token_card.copy_token"))
            },
            onRegister: { [weak self] in
                guard self != nil else { return }
                PushNotificationManager.shared.registerForPushNotifications()
            }
        )

        actionTileGrid.configure(actions: [
            (.scan, L10n.tr("home.quick_action.scan"), .primary),
            (.clipboard, L10n.tr("home.quick_action.paste"), .warning),
            (.inbox, L10n.tr("home.quick_action.inbox"), .default),
            (.ellipsis, L10n.tr("home.quick_action.more"), .success)
        ], onTap: { [weak self] index in
            self?.handleQuickAction(index: index)
        })

        favoritesSection.isHidden = true
        recentSection.isHidden = true

        emptyStateView.configure(
            icon: "square.grid.2x2.fill",
            title: L10n.tr("home.empty.title"),
            description: L10n.tr("home.empty.description"),
            actionTitle: nil
        )
    }

    private func setupOverlays() {
        view.addSubview(emptyStateView)
        view.addSubview(loadingView)
        view.addSubview(commandBanner)

        emptyStateView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        loadingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        commandBanner.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.leading.trailing.equalToSuperview().inset(ThemeTokens.Spacing.screenHorizontal)
            make.height.equalTo(44)
        }
        commandBanner.alpha = 0
        commandBanner.transform = CGAffineTransform(translationX: 0, y: -44)
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
        if UIAccessibility.isReduceMotionEnabled {
            self.commandBanner.alpha = 1
            self.commandBanner.transform = .identity
        } else {
            UIView.animate(withDuration: ThemeTokens.Animation.slow.duration) {
                self.commandBanner.alpha = 1
                self.commandBanner.transform = .identity
            }
        }
    }

    private func hideCommandBanner() {
        pendingCommandTitle = nil
        guard !commandBanner.isHidden else { return }
        if UIAccessibility.isReduceMotionEnabled {
            self.commandBanner.alpha = 0
            self.commandBanner.isHidden = true
        } else {
            UIView.animate(withDuration: ThemeTokens.Animation.normal.duration, animations: {
                self.commandBanner.alpha = 0
                self.commandBanner.transform = CGAffineTransform(translationX: 0, y: -self.commandBanner.bounds.height)
            }, completion: { _ in
                self.commandBanner.isHidden = true
            })
        }
    }

    private func executePendingCommand() {
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

    private func setupGestures() {
        // pull-to-refresh not needed with scaffold; kept for refreshData
    }

    override func bindViewModel() {
        Log.debug("bindViewModel called", category: .ui)

        let viewWillAppearTrigger = rx.methodInvoked(#selector(UIViewController.viewWillAppear(_:)))
            .map { _ in () }
            .asDriver(onErrorJustReturn: ())

        let refreshTrigger = Driver.merge(viewWillAppearTrigger)

        let input = MainViewModel.Input(
            refresh: refreshTrigger,
            itemSelect: Driver.empty(),
            itemLongPress: Driver.empty(),
            scanButtonTap: Driver.empty()
        )

        let output = viewModel.transform(input: input)

        output.histories
            .drive(onNext: { [weak self] sections in
                self?.updateSections(sections)
            })
            .disposed(by: rx)

        output.isEmpty
            .drive(onNext: { [weak self] (isEmpty: Bool) in
                guard let self = self else { return }
                if isEmpty {
                    self.view.bringSubviewToFront(self.emptyStateView)
                    self.emptyStateView.isHidden = false
                    self.scaffold.isHidden = true
                    self.scaffold.alpha = 0
                } else {
                    self.emptyStateView.isHidden = true
                    self.scaffold.isHidden = false
                    self.scaffold.alpha = 1
                    self.view.bringSubviewToFront(self.scaffold)
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
            .drive(onNext: { _ in
            })
            .disposed(by: rx)

        viewModel.totalStorageSizeRelay
            .asDriver(onErrorJustReturn: "")
            .drive(onNext: { [weak self] sizeText in
                self?.storageInfoButton.setTitle(sizeText.isEmpty ? "0 MB" : sizeText, for: .normal)
            })
            .disposed(by: rx)
    }

    private func updateSections(_ sections: [WebPageHistorySection]) {
        currentSections = sections

        var favoritesItems: [WebPageHistorySectionItem] = []
        var recentItems: [WebPageHistorySectionItem] = []

        for section in sections {
            let isFavorite = section.header.contains("收藏")
            if isFavorite {
                favoritesItems.append(contentsOf: section.items)
            } else {
                recentItems.append(contentsOf: section.items)
            }
        }

        if favoritesItems.isEmpty {
            favoritesSection.isHidden = true
        } else {
            favoritesSection.isHidden = false
            let header = WBKSectionHeader(title: L10n.tr("home.section.favorites"), style: .withCount)
            header.setCount(favoritesItems.count)
            let cards = favoritesItems.map { item -> WBKResourceCard in
                makeResourceCard(from: item)
            }
            favoritesSection.configure(header: header, cards: cards)
        }

        if recentItems.isEmpty {
            recentSection.isHidden = true
        } else {
            recentSection.isHidden = false
            let header = WBKSectionHeader(title: L10n.tr("home.section.recent_visits"), style: .withCount)
            header.setCount(recentItems.count)
            let cards = recentItems.map { item -> WBKResourceCard in
                makeResourceCard(from: item)
            }
            recentSection.configure(header: header, cards: cards)
        }

        serverStatusBlock.configure(
            serverURL: pushURL,
            deviceToken: deviceToken,
            isRegistered: isTokenRegistered,
            onCopy: { [weak self] in
                UIPasteboard.general.string = self?.pushURL ?? ""
                HUDService.shared.showSuccess(withStatus: L10n.tr("home.token_card.copy_token"))
            },
            onRegister: { [weak self] in
                guard self != nil else { return }
                PushNotificationManager.shared.registerForPushNotifications()
            }
        )
    }

    private func makeResourceCard(from item: WebPageHistorySectionItem) -> WBKResourceCard {
        let history = item.history
        let title = history.title ?? history.url
        let card = WBKResourceCard(title: title, style: .compact)

        if let url = URL(string: history.url) {
            card.metadata = url.host
        }

        if history.isCached {
            card.status = .cached
        }

        let cacheSize = ByteCountFormatter.string(fromByteCount: max(0, history.cachedSize), countStyle: .file)
        if history.cachedSize > 0 {
            card.subtitle = cacheSize
        }

        card.onTap = { [weak self] in
            guard let self = self, let url = URL(string: history.url) else { return }
            self.openURL(url)
        }

        let longPress = UILongPressGestureRecognizer()
        card.addGestureRecognizer(longPress)
        longPress.rx.event
            .filter { $0.state == .began }
            .subscribe(onNext: { [weak self] _ in
                guard let self = self, let url = URL(string: history.url) else { return }
                self.showActionSheet(url: url)
            })
            .disposed(by: rx)

        return card
    }

    @objc private func refreshData() {
        Log.debug("refreshData triggered", category: .ui)
    }

    func openURL(_ url: URL) {
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


}
