//
//  CacheResourceViewModel.swift
//  SuperApp
//
//  Created on 2025-01-29.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import RxCocoa
import RxSwift
import UIKit
import RealmSwift

/// 缓存资源视图模型
public class CacheResourceViewModel: ViewModel {

    // MARK: - Input & Output

    public struct Input {
        let loadResources: Driver<URL>
        let selectAll: Driver<Void>
        let deselectAll: Driver<Void>
        let deleteSelected: Driver<Void>
        let clearAll: Driver<Void>
        let itemDelete: Driver<String>
    }

    public struct Output {
        let resources: Driver<[CacheResourceSection]>
        let isEmpty: Driver<Bool>
        let selectedCount: Driver<Int>
        let totalCount: Driver<String>
        let loading: Driver<Bool>
        let deletionCompleted: Driver<Void>
    }

    // MARK: - Properties

    private let historyManager: WebPageHistoryManager
    private let cacheManager: WebPageOfflineCacheManager

    private let resourcesRelay = BehaviorRelay<[CacheResourceSection]>(value: [])
    private let isEmptyRelay = BehaviorRelay<Bool>(value: true)
    private let selectedCountRelay = BehaviorRelay<Int>(value: 0)
    private let totalCountRelay = BehaviorRelay<String>(value: "0 个资源")
    private let loadingRelay = BehaviorRelay<Bool>(value: false)
    private let deletionCompletedRelay = PublishRelay<Void>()

    private var selectedResources: Set<String> = []

    // MARK: - Initialization

    override init() {
        self.historyManager = WebPageHistoryManager.shared
        self.cacheManager = WebPageOfflineCacheManager.shared
        super.init()
    }

    // MARK: - Transform

    public func transform(input: Input) -> Output {
        // 加载资源
        input.loadResources
            .do(onNext: { [weak self] url in
                self?.loadingRelay.accept(true)
                self?.loadResources(for: url)
            })
            .drive()
            .disposed(by: rx)

        // 全选
        input.selectAll
            .do(onNext: { [weak self] in
                self?.selectAllResources()
            })
            .drive()
            .disposed(by: rx)

        // 取消全选
        input.deselectAll
            .do(onNext: { [weak self] in
                self?.deselectAllResources()
            })
            .drive()
            .disposed(by: rx)

        // 删除选中
        input.deleteSelected
            .do(onNext: { [weak self] in
                self?.deleteSelectedResources()
            })
            .drive()
            .disposed(by: rx)

        // 清空所有
        input.clearAll
            .do(onNext: { [weak self] in
                self?.clearAllResources()
            })
            .drive()
            .disposed(by: rx)

        // 删除单个项目
        input.itemDelete
            .do(onNext: { [weak self] key in
                self?.deleteResource(key: key)
            })
            .drive()
            .disposed(by: rx)

        return Output(
            resources: resourcesRelay.asDriver(onErrorJustReturn: []),
            isEmpty: isEmptyRelay.asDriver(onErrorJustReturn: true),
            selectedCount: selectedCountRelay.asDriver(onErrorJustReturn: 0),
            totalCount: totalCountRelay.asDriver(onErrorJustReturn: ""),
            loading: loadingRelay.asDriver(onErrorJustReturn: false),
            deletionCompleted: deletionCompletedRelay.asDriver(onErrorJustReturn: ())
        )
    }

    // MARK: - Public Methods

    /// 切换资源选择状态
    public func toggleSelection(key: String) {
        if selectedResources.contains(key) {
            selectedResources.remove(key)
        } else {
            selectedResources.insert(key)
        }
        selectedCountRelay.accept(selectedResources.count)
    }

    /// 检查资源是否被选中
    public func isSelected(key: String) -> Bool {
        return selectedResources.contains(key)
    }

    // MARK: - Private Methods

    private func loadResources(for url: URL) {
        Task { [weak self] in
            guard let self = self else { return }
            guard let history = try? await WebPageHistoryManager.shared.findHistory(url: url) else {
                self.resourcesRelay.accept([])
                self.isEmptyRelay.accept(true)
                self.totalCountRelay.accept("0 个资源")
                self.loadingRelay.accept(false)
                return
            }

            var items: [CacheResourceItem] = []

            if let htmlPath = history.htmlPath {
                let fileSize = self.getFileSize(path: htmlPath)
                items.append(CacheResourceItem(
                    key: "html",
                    url: url.absoluteString,
                    type: .html,
                    size: fileSize,
                    compressedSize: nil,
                    date: history.cacheDate ?? Date()
                ))
            }

            for resourcePath in history.resourcePaths {
                let fileName = (resourcePath as NSString).lastPathComponent
                let fileSize = self.getFileSize(path: resourcePath)
                let fileType = self.guessFileType(from: fileName)

                items.append(CacheResourceItem(
                    key: resourcePath,
                    url: resourcePath,
                    type: fileType,
                    size: fileSize,
                    compressedSize: nil,
                    date: history.cacheDate ?? Date()
                ))
            }

            let grouped = Dictionary(grouping: items) { $0.type }

            var sections: [CacheResourceSection] = []

            let typeOrder: [CacheFileResourceType] = [.html, .script, .stylesheet, .image, .font, .other]
            for type in typeOrder {
                if let items = grouped[type], !items.isEmpty {
                    sections.append(CacheResourceSection(
                        type: type,
                        items: items.sorted { $0.url < $1.url }
                    ))
                }
            }

            self.resourcesRelay.accept(sections)
            self.isEmptyRelay.accept(items.isEmpty)
            self.totalCountRelay.accept("\(items.count) 个资源")
            self.loadingRelay.accept(false)
        }
    }

    private func selectAllResources() {
        guard !resourcesRelay.value.isEmpty else { return }
        for section in resourcesRelay.value {
            for item in section.items {
                selectedResources.insert(item.key)
            }
        }
        selectedCountRelay.accept(selectedResources.count)
    }

    public func deselectAllResources() {
        selectedResources.removeAll()
        selectedCountRelay.accept(0)
    }

    public func deleteSelectedResources() {
        for key in selectedResources {
            deleteResource(key: key)
        }
        selectedResources.removeAll()
        selectedCountRelay.accept(0)
        deletionCompletedRelay.accept(())
    }

    public func clearAllResources() {
        guard !resourcesRelay.value.isEmpty else { return }
        for section in resourcesRelay.value {
            for item in section.items {
                deleteResource(key: item.key)
            }
        }
        selectedResources.removeAll()
        selectedCountRelay.accept(0)
        resourcesRelay.accept([])
        isEmptyRelay.accept(true)
        totalCountRelay.accept("0 个资源")
        deletionCompletedRelay.accept(())
    }

    public func deleteResource(key: String) {
        try? FileManager.default.removeItem(atPath: key)

        Task {
            let allHistories = (try? await WebPageHistoryManager.shared.getAllHistories()) ?? []
            guard let history = allHistories.first(where: { h in
                h.resourcePaths.contains(key) || h.htmlPath == key
            }) else { return }

            if key == history.htmlPath {
                await MainActor.run {
                    cacheManager.deleteCache(history: history)
                }
            } else {
                await MainActor.run {
                    let realm = try? Realm(configuration: WebPageHistoryManager.shared.realmConfiguration)
                    try? realm?.write {
                        if let cachedHistory = realm?.object(ofType: WebPageHistory.self, forPrimaryKey: history.id) {
                            let index = cachedHistory.resourcePaths.index(of: key)
                            if let index = index {
                                cachedHistory.resourcePaths.remove(at: index)
                            }
                        }
                    }
                }
            }
        }
    }

    private func getFileSize(path: String) -> Int64 {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let fileSize = attributes[.size] as? Int64 else {
            return 0
        }
        return fileSize
    }

    private func guessFileType(from fileName: String) -> CacheFileResourceType {
        let pathExtension = (fileName as NSString).pathExtension.lowercased()

        switch pathExtension {
        case "js", "mjs":
            return .script
        case "css":
            return .stylesheet
        case "png", "jpg", "jpeg", "gif", "webp", "svg", "ico":
            return .image
        case "woff", "woff2", "ttf", "otf", "eot":
            return .font
        case "html", "htm":
            return .html
        default:
            return .other
        }
    }
}

// MARK: - Models

/// 缓存资源类型
public enum CacheFileResourceType {
    case html
    case script
    case stylesheet
    case image
    case font
    case other

    var displayName: String {
        switch self {
        case .html: return "HTML"
        case .script: return "JavaScript"
        case .stylesheet: return "CSS"
        case .image: return "图片"
        case .font: return "字体"
        case .other: return "其他"
        }
    }

    var iconName: String {
        switch self {
        case .html: return "doc.text"
        case .script: return "doc.text.image"
        case .stylesheet: return "paintbrush"
        case .image: return "photo"
        case .font: return "textformat"
        case .other: return "doc"
        }
    }

    var iconColor: UIColor {
        switch self {
        case .html: return ThemeTokens.Color.primary
        case .script: return ThemeTokens.Color.warning
        case .stylesheet: return ThemeTokens.Color.error.withAlphaComponent(0.7)
        case .image: return ThemeTokens.Color.gradientEnd
        case .font: return ThemeTokens.Color.warning
        case .other: return ThemeTokens.Color.textSecondary
        }
    }
}

/// 缓存资源项
public struct CacheResourceItem {
    public let key: String
    public let url: String
    public let type: CacheFileResourceType
    public let size: Int64
    public let compressedSize: Int64?
    public let date: Date

    public var formattedSize: String {
        if let compressed = compressedSize {
            let saved = size - compressed
            let savedPercent = Int((Double(saved) / Double(size)) * 100)
            return "\(ByteCountFormatter.string(fromByteCount: compressed, countStyle: .file)) (节省 \(savedPercent)%)"
        }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    public var fileName: String {
        return (url as NSString).lastPathComponent
    }
}

/// 缓存资源分组
public struct CacheResourceSection {
    public let type: CacheFileResourceType
    public let items: [CacheResourceItem]

    public var totalSize: Int64 {
        return items.reduce(0) { $0 + $1.size }
    }

    public var formattedTotalSize: String {
        return ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
}
