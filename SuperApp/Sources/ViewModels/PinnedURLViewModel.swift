//
//  PinnedURLViewModel.swift
//  SuperApp
//

import Foundation
import RxCocoa
import RxDataSources
import RxSwift
import WebBridgeKit

class PinnedURLViewModel: ViewModel {

    struct Input {
        let loadTrigger: Observable<Void>
        let addURL: Observable<String>
        let deleteTapped: Observable<PinnedURLRealm>
        let unpinTapped: Observable<PinnedURLRealm>
        let searchQuery: Observable<String>
        let filterType: Observable<URLType?>
        let importPreset: Observable<PresetURLItem>
    }

    struct Output {
        let pinnedURLs: Driver<[PinnedURLSection]>
        let isEmpty: Driver<Bool>
        let summaryText: Driver<String>
        let detectedType: Driver<(url: String, type: URLType)>
        let addResult: Driver<Result<PinnedURLRealm, Error>>
        let deleteResult: Driver<Bool>
        let error: Driver<String?>
    }

    typealias PinnedURLSection = SectionModel<String, PinnedURLItemModel>

    struct PinnedURLItemModel: IdentifiableType, Equatable {
        var identity: String { id }
        let id: String
        let url: String
        let title: String
        let domain: String
        let urlType: URLType
        let iconName: String
        let typeName: String
        let accessCount: Int
        let formattedDate: String
        let isPinned: Bool
        let tags: [String]

        init(from realm: PinnedURLRealm) {
            self.id = realm.id
            self.url = realm.url
            self.title = realm.displayTitle
            self.domain = realm.domain
            self.urlType = realm.urlType
            self.iconName = realm.urlType.iconName
            self.typeName = realm.urlType.displayName
            self.accessCount = realm.accessCount
            let f = DateFormatter()
            f.dateStyle = .medium
            f.timeStyle = .short
            self.formattedDate = f.string(from: realm.lastAccessedAt)
            self.isPinned = realm.isPinned
            self.tags = realm.tags.map { $0 }
        }
    }

    private let urlsRelay = BehaviorRelay<[PinnedURLRealm]>(value: [])
    private let errorRelay = BehaviorRelay<String?>(value: nil)
    private let detectedTypeRelay = BehaviorRelay<(String, URLType)?>(value: nil)
    private let addResultRelay = BehaviorRelay<Result<PinnedURLRealm, Error>?>(value: nil)
    private let deleteResultRelay = BehaviorRelay<Bool>(value: false)

    func transform(input: Input) -> Output {
        input.loadTrigger
            .flatMap { _ -> Observable<[PinnedURLRealm]> in
                Observable.create { observer in
                    Task {
                        let urls = (try? await PinnedURLManager.shared.getAllPinned()) ?? []
                        observer.onNext(urls)
                        observer.onCompleted()
                    }
                    return Disposables.create()
                }
            }
            .bind(to: urlsRelay)
            .disposed(by: rx)

        input.addURL
            .filter { !$0.isEmpty }
            .do(onNext: { [weak self] url in
                let type = URLType.detect(from: url)
                self?.detectedTypeRelay.accept((url, type))
            })
            .flatMap { [weak self] url -> Observable<Result<PinnedURLRealm, Error>> in
                guard let self else {
                    return .just(.failure(NSError(domain: "PinnedURL", code: -1)))
                }
                return Observable.create { observer in
                    Task {
                        do {
                            let result = try await PinnedURLManager.shared.add(url: url)
                            let urls = (try? await PinnedURLManager.shared.getAllPinned()) ?? []
                            self.urlsRelay.accept(urls)
                            observer.onNext(.success(result))
                        } catch {
                            observer.onNext(.failure(error))
                        }
                        observer.onCompleted()
                    }
                    return Disposables.create()
                }
            }
            .bind(to: addResultRelay)
            .disposed(by: rx)

        input.deleteTapped
            .flatMap { [weak self] item -> Observable<Bool> in
                guard let self else { return .just(false) }
                return Observable.create { observer in
                    Task {
                        do {
                            try await PinnedURLManager.shared.delete(id: item.id)
                            let urls = (try? await PinnedURLManager.shared.getAllPinned()) ?? []
                            self.urlsRelay.accept(urls)
                            observer.onNext(true)
                        } catch {
                            self.errorRelay.accept(error.localizedDescription)
                            observer.onNext(false)
                        }
                        observer.onCompleted()
                    }
                    return Disposables.create()
                }
            }
            .bind(to: deleteResultRelay)
            .disposed(by: rx)

        input.unpinTapped
            .flatMap { [weak self] item -> Observable<Bool> in
                guard let self else { return .just(false) }
                return Observable.create { observer in
                    Task {
                        do {
                            try await PinnedURLManager.shared.unpin(id: item.id)
                            let urls = (try? await PinnedURLManager.shared.getAllPinned()) ?? []
                            self.urlsRelay.accept(urls)
                            observer.onNext(true)
                        } catch {
                            self.errorRelay.accept(error.localizedDescription)
                            observer.onNext(false)
                        }
                        observer.onCompleted()
                    }
                    return Disposables.create()
                }
            }
            .bind(to: deleteResultRelay)
            .disposed(by: rx)

        input.importPreset
            .flatMap { [weak self] preset -> Observable<Result<PinnedURLRealm, Error>> in
                guard let self else {
                    return .just(.failure(NSError(domain: "PinnedURL", code: -1)))
                }
                return Observable.create { observer in
                    Task {
                        do {
                            let result = try await PinnedURLManager.shared.add(url: preset.url, title: preset.title, notes: preset.description)
                            let urls = (try? await PinnedURLManager.shared.getAllPinned()) ?? []
                            self.urlsRelay.accept(urls)
                            observer.onNext(.success(result))
                        } catch {
                            observer.onNext(.failure(error))
                        }
                        observer.onCompleted()
                    }
                    return Disposables.create()
                }
            }
            .bind(to: addResultRelay)
            .disposed(by: rx)

        let filteredURLs = Observable.combineLatest(
            urlsRelay.asObservable(),
            input.searchQuery.startWith(""),
            input.filterType.startWith(nil)
        ) { urls, query, type -> [PinnedURLRealm] in
            var result = urls

            if let t = type {
                result = result.filter { $0.urlType == t }
            }

            let q = query.lowercased().trimmingCharacters(in: .whitespaces)
            if !q.isEmpty {
                result = result.filter {
                    $0.url.lowercased().contains(q) ||
                    ($0.title?.lowercased().contains(q) ?? false) ||
                    $0.domain.lowercased().contains(q)
                }
            }

            return result
        }

        let sections = filteredURLs
            .map { urls -> [PinnedURLSection] in
                let grouped = Dictionary(grouping: urls) { $0.urlType.displayName }
                return grouped.map { typeName, items in
                    SectionModel(model: "\(typeName) (\(items.count))", items: items.map { PinnedURLItemModel(from: $0) })
                }.sorted { $0.model < $1.model }
            }

        let summary = urlsRelay
            .map { "\($0.count) 个置顶 URL" }
            .asDriver(onErrorJustReturn: "")

        return Output(
            pinnedURLs: sections.asDriver(onErrorJustReturn: []),
            isEmpty: urlsRelay.map(\.isEmpty).asDriver(onErrorJustReturn: true),
            summaryText: summary,
            detectedType: detectedTypeRelay.compactMap { $0 }.asDriver(onErrorJustReturn: ("", .other)),
            addResult: addResultRelay.compactMap { $0 }.asDriver(onErrorJustReturn: .failure(NSError(domain: "PinnedURL", code: -1))),
            deleteResult: deleteResultRelay.asDriver(onErrorJustReturn: false),
            error: errorRelay.asDriver(onErrorJustReturn: nil)
        )
    }
}
