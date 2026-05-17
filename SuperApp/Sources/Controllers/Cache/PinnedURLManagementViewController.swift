//
//  PinnedURLManagementViewController.swift
//  SuperApp
//
//  Created on 2026-05-11.
//  Copyright © 2026年 WebBridgeKit. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import RxDataSources
import SnapKit
import WebBridgeKit

/// 置顶 URL 管理页面
class PinnedURLManagementViewController: BaseViewController<PinnedURLViewModel> {

    // MARK: - UI
    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.backgroundColor = ThemeTokens.Color.background
        tv.register(PinnedURLCell.self, forCellReuseIdentifier: PinnedURLCell.reuseIdentifier)
        return tv
    }()

    private let urlInputHeader = URLInputHeaderView()
    private let searchController: UISearchController = {
        let sc = UISearchController(searchResultsController: nil)
        sc.obscuresBackgroundDuringPresentation = false
        sc.searchBar.placeholder = "搜索置顶 URL..."
        return sc
    }()

    private let emptyStateView: UIView = {
        let v = UIView()
        v.isHidden = true
        return v
    }()

    private let emptyIconLabel: UILabel = {
        let l = UILabel()
        l.text = "📌"
        l.font = UIFont.preferredFont(forTextStyle: .largeTitle)
        return l
    }()

    private let emptyTitleLabel: UILabel = {
        let l = UILabel()
        l.text = "暂无置顶 URL"
        l.font = UIFont.preferredFont(forTextStyle: .headline)
        l.textColor = ThemeTokens.Color.textSecondary
        return l
    }()

    private let emptyDescLabel: UILabel = {
        let l = UILabel()
        l.text = "从预设目录添加，或手动输入 URL\n置顶的 URL 在缓存清理时不会被删除"
        l.font = UIFont.preferredFont(forTextStyle: .caption1)
        l.textColor = ThemeTokens.Color.textTertiary
        l.textAlignment = .center
        l.numberOfLines = 0
        return l
    }()

    private lazy var addFromPresetButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("📚 从预设目录添加", for: .normal)
        btn.titleLabel?.font = UIFont.preferredFont(forTextStyle: .subheadline)
        btn.setTitleColor(ThemeTokens.Color.primary, for: .normal)
        btn.layer.cornerRadius = ThemeTokens.CornerRadius.md
        btn.backgroundColor = ThemeTokens.Color.surface
        btn.layer.borderWidth = 1
        btn.layer.borderColor = ThemeTokens.Color.primary.cgColor
        btn.contentEdgeInsets = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        return btn
    }()

    // MARK: - Data
    private var dataSource: RxTableViewSectionedReloadDataSource<PinnedURLViewModel.PinnedURLSection>?
    private let deleteRelay = PublishRelay<PinnedURLRealm>()
    private let unpinRelay = PublishRelay<PinnedURLRealm>()
    private let addURLRelay = PublishRelay<String>()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "置顶 URL 管理"
        view.backgroundColor = ThemeTokens.Color.background

        setupUI()
        setupNavigation()
    }

    override func bindViewModel() {
        dataSource = RxTableViewSectionedReloadDataSource<PinnedURLViewModel.PinnedURLSection>(
            configureCell: { _, tableView, indexPath, item in
                let cell = tableView.dequeueReusableCell(withIdentifier: PinnedURLCell.reuseIdentifier, for: indexPath) as! PinnedURLCell
                cell.configure(with: item)
                return cell
            }
        )

        let input = PinnedURLViewModel.Input(
            loadTrigger: Observable.just(()),
            addURL: addURLRelay.asObservable(),
            deleteTapped: deleteRelay.asObservable(),
            unpinTapped: unpinRelay.asObservable(),
            searchQuery: searchController.searchBar.rx.text.orEmpty.debounce(.milliseconds(300), scheduler: MainScheduler.instance),
            filterType: .empty(),
            importPreset: .empty()
        )

        let output: PinnedURLViewModel.Output = viewModel.transform(input: input)

        output.pinnedURLs
            .drive(tableView.rx.items(dataSource: dataSource!))
            .disposed(by: rx)

        output.isEmpty
            .drive(onNext: { [weak self] (empty: Bool) in
                guard let self else { return }
                self.emptyStateView.isHidden = !empty
                self.tableView.backgroundView = empty ? self.emptyStateView : nil
            })
            .disposed(by: rx)

        output.summaryText
            .drive(navigationItem.rx.prompt)
            .disposed(by: rx)

        output.error
            .drive(onNext: { (error: String?) in
                if let error, !error.isEmpty {
                    print("[PinnedURL] Error: \(error)")
                }
            })
            .disposed(by: rx)
    }

    // MARK: - Setup
    private func setupUI() {
        view.addSubview(tableView)
        view.addSubview(emptyStateView)

        emptyStateView.addSubview(emptyIconLabel)
        emptyStateView.addSubview(emptyTitleLabel)
        emptyStateView.addSubview(emptyDescLabel)
        emptyStateView.addSubview(addFromPresetButton)

        tableView.snp.makeConstraints { $0.edges.equalToSuperview() }

        [emptyStateView, emptyIconLabel, emptyTitleLabel, emptyDescLabel, addFromPresetButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateView.widthAnchor.constraint(lessThanOrEqualToConstant: 280),

            emptyIconLabel.topAnchor.constraint(equalTo: emptyStateView.topAnchor),
            emptyIconLabel.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),

            emptyTitleLabel.topAnchor.constraint(equalTo: emptyIconLabel.bottomAnchor, constant: 12),
            emptyTitleLabel.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),

            emptyDescLabel.topAnchor.constraint(equalTo: emptyTitleLabel.bottomAnchor, constant: 8),
            emptyDescLabel.leadingAnchor.constraint(equalTo: emptyStateView.leadingAnchor),
            emptyDescLabel.trailingAnchor.constraint(equalTo: emptyStateView.trailingAnchor),

            addFromPresetButton.topAnchor.constraint(equalTo: emptyDescLabel.bottomAnchor, constant: 20),
            addFromPresetButton.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            addFromPresetButton.bottomAnchor.constraint(equalTo: emptyStateView.bottomAnchor)
        ])

        // URL Input Header as table header
        urlInputHeader.onSubmit = { [weak self] url in
            self?.addURL(url)
        }
        urlInputHeader.onTextChanged = { _, _ in }

        let inputContainer = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 52))
        inputContainer.addSubview(urlInputHeader)
        urlInputHeader.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        tableView.tableHeaderView = inputContainer

        // DataSource
        dataSource = RxTableViewSectionedReloadDataSource<PinnedURLViewModel.PinnedURLSection>(
            configureCell: { _, tableView, indexPath, item in
                let cell = tableView.dequeueReusableCell(withIdentifier: PinnedURLCell.reuseIdentifier, for: indexPath) as! PinnedURLCell
                cell.configure(with: item)
                return cell
            },
            titleForHeaderInSection: { ds, index in
                ds.sectionModels[index].model
            }
        )

        // Swipe actions
        addFromPresetButton.rx.tap.subscribe(onNext: { [weak self] in
            self?.navigateToPresetCatalog()
        }).disposed(by: rx)
    }

    private func setupNavigation() {
        navigationItem.searchController = searchController
        definesPresentationContext = true

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addTapped)
        )
    }

    @objc private func addTapped() {
        urlInputHeader.becomeFirstResponder()
    }

    // MARK: - Actions
    private func addURL(_ urlString: String) {
        addURLRelay.accept(urlString)

        let type = URLType.detect(from: urlString)
        let alert = UIAlertController(
            title: "已添加",
            message: "\(urlString)\n类型: \(type.displayName)\n该 URL 将在缓存清理时被保留",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "好的", style: .default))
        present(alert, animated: true)
    }

    private func deletePinned(id: String) {
        Task { [weak self] in
            guard let self else { return }
            guard let urls = try? await PinnedURLManager.shared.getAllPinned(),
                  let item = urls.first(where: { $0.id == id }) else { return }
            self.deleteRelay.accept(item)
        }
    }

    private func unpinPinned(id: String) {
        Task { [weak self] in
            guard let self else { return }
            guard let urls = try? await PinnedURLManager.shared.getAllPinned(),
                  let item = urls.first(where: { $0.id == id }) else { return }
            self.unpinRelay.accept(item)
        }
    }

    private func navigateToPresetCatalog() {
        let vc = PresetURLCatalogViewController(viewModel: PresetURLCatalogViewModel())
        navigationController?.pushViewController(vc, animated: true)
    }
}

// MARK: - UITableViewDelegate
extension PinnedURLManagementViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let delete = UIContextualAction(style: .destructive, title: "删除") { [weak self] _, _, completion in
            guard let self else { completion(false); return }
            guard let dataSource = self.dataSource,
                  let item = try? dataSource.model(at: indexPath) as? PinnedURLViewModel.PinnedURLItemModel else {
                completion(false); return
            }
            self.deletePinned(id: item.id)
            completion(true)
        }

        let unpin = UIContextualAction(style: .normal, title: "取消置顶") { [weak self] _, _, completion in
            guard let self else { completion(false); return }
            guard let dataSource = self.dataSource,
                  let item = try? dataSource.model(at: indexPath) as? PinnedURLViewModel.PinnedURLItemModel else {
                completion(false); return
            }
            self.unpinPinned(id: item.id)
            completion(true)
        }
        unpin.backgroundColor = ThemeTokens.Color.secondary

        return UISwipeActionsConfiguration(actions: [delete, unpin])
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 72
    }
}
