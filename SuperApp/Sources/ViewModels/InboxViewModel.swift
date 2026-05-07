//
//  InboxViewModel.swift
//  SuperApp
//
//  Created on 2026-05-07.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import RxCocoa
import RxSwift
import WebBridgeKit

class InboxViewModel: ViewModel {

    struct Input {
        let refresh: Driver<Void>
        let searchTextChanged: Driver<String>
        let filterSelected: Driver<FilterType>
        let itemSelect: Driver<IndexPath>
        let deleteItem: Driver<IndexPath>
        let markAllRead: Driver<Void>
        let sendTestNotification: Driver<Void>
    }

    struct Output {
        let messageGroups: Driver<[MessageGroup]>
        let isEmpty: Driver<Bool>
        let selectedMessage: Driver<StoredMessage>
        let unreadCount: Driver<Int>
        let reloadData: Driver<Void>
    }

    enum FilterType: Int {
        case all = 0
        case unread
        case today
    }

    struct MessageGroup {
        let name: String
        var messages: [StoredMessage]
        var isExpanded: Bool = true

        var mostRecentDate: Date {
            messages.map(\.receivedAt).max() ?? .distantPast
        }

        var unreadCount: Int {
            messages.filter { !$0.isRead }.count
        }
    }

    private let messagesRelay = BehaviorRelay<[StoredMessage]>(value: [])
    private let messageGroupsRelay = BehaviorRelay<[MessageGroup]>(value: [])
    private let isEmptyRelay = BehaviorRelay<Bool>(value: true)
    private let selectedMessageRelay = PublishRelay<StoredMessage>()
    private let unreadCountRelay = BehaviorRelay<Int>(value: 0)
    private let reloadDataRelay = PublishRelay<Void>()

    private var searchText: String = ""
    private var currentFilter: FilterType = .all
    private var searchDebounceWorkItem: DispatchWorkItem?

    var messageGroupsValue: [MessageGroup] {
        return messageGroupsRelay.value
    }

    func transform(input: Input) -> Output {
        input.refresh
            .do(onNext: { [weak self] in
                self?.loadMessages()
            })
            .drive()
            .disposed(by: rx)

        input.searchTextChanged
            .do(onNext: { [weak self] text in
                self?.debounceSearch(text)
            })
            .drive()
            .disposed(by: rx)

        input.filterSelected
            .do(onNext: { [weak self] filter in
                self?.currentFilter = filter
                self?.applyFilters()
            })
            .drive()
            .disposed(by: rx)

        input.itemSelect
            .withLatestFrom(messageGroupsRelay.asDriver()) { indexPath, groups -> StoredMessage? in
                guard indexPath.section < groups.count else { return nil }
                let group = groups[indexPath.section]
                guard indexPath.row < group.messages.count else { return nil }
                return group.messages[indexPath.row]
            }
            .compactMap { $0 }
            .do(onNext: { [weak self] message in
                self?.markAsRead(id: message.id)
                self?.selectedMessageRelay.accept(message)
            })
            .drive()
            .disposed(by: rx)

        input.deleteItem
            .do(onNext: { [weak self] indexPath in
                guard let self = self else { return }
                let message = self.messageAt(indexPath)
                Task {
                    await MessageEngine.shared.deleteMessage(id: message.id)
                    self.loadMessages()
                }
            })
            .drive()
            .disposed(by: rx)

        input.markAllRead
            .do(onNext: { [weak self] in
                Task {
                    let messages = await MessageEngine.shared.getMessages()
                    for message in messages where !message.isRead {
                        await MessageEngine.shared.markAsRead(id: message.id)
                    }
                    self?.loadMessages()
                }
            })
            .drive()
            .disposed(by: rx)

        input.sendTestNotification
            .do(onNext: { [weak self] in
                self?.sendTestMessage()
            })
            .drive()
            .disposed(by: rx)

        loadMessages()

        return Output(
            messageGroups: messageGroupsRelay.asDriver(),
            isEmpty: isEmptyRelay.asDriver(),
            selectedMessage: selectedMessageRelay.asDriver(onErrorDriveWith: .empty()),
            unreadCount: unreadCountRelay.asDriver(),
            reloadData: reloadDataRelay.asDriver(onErrorJustReturn: ())
        )
    }

    func refreshData() {
        loadMessages()
    }

    func messageAt(_ indexPath: IndexPath) -> StoredMessage {
        let groups = messageGroupsRelay.value
        guard indexPath.section < groups.count else { fatalError("Section out of bounds") }
        let group = groups[indexPath.section]
        guard indexPath.row < group.messages.count else { fatalError("Row out of bounds") }
        return group.messages[indexPath.row]
    }

    func numberOfRows() -> Int {
        return messageGroupsRelay.value.reduce(0) { $0 + ($1.isExpanded ? $1.messages.count : 0) }
    }

    func numberOfGroups() -> Int {
        return messageGroupsRelay.value.count
    }

    func isGroupExpanded(_ index: Int) -> Bool {
        guard index < messageGroupsRelay.value.count else { return true }
        return messageGroupsRelay.value[index].isExpanded
    }

    func toggleGroup(_ index: Int) {
        var groups = messageGroupsRelay.value
        guard index < groups.count else { return }
        groups[index].isExpanded.toggle()
        messageGroupsRelay.accept(groups)
    }

    func groupHeaderTitle(_ index: Int) -> String {
        guard index < messageGroupsRelay.value.count else { return "" }
        let group = messageGroupsRelay.value[index]
        let unread = group.unreadCount
        return "\(group.name) (\(group.messages.count))" + (unread > 0 ? " · \(unread) \(L10n.tr("inbox.filter.unread").lowercased())" : "")
    }

    func numberOfRowsInGroup(_ index: Int) -> Int {
        guard index < messageGroupsRelay.value.count else { return 0 }
        let group = messageGroupsRelay.value[index]
        return group.isExpanded ? group.messages.count : 0
    }

    func messageIndexPath(globalRow row: Int) -> (group: Int, localRow: Int)? {
        var offset = 0
        for (gi, group) in messageGroupsRelay.value.enumerated() where group.isExpanded {
            if row >= offset && row < offset + group.messages.count {
                return (gi, row - offset)
            }
            offset += group.messages.count
        }
        return nil
    }

    private func debounceSearch(_ text: String) {
        searchDebounceWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.searchText = text
            self?.applyFilters()
            self?.reloadDataRelay.accept(())
        }
        searchDebounceWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: item)
    }

    private func loadMessages() {
        Task { [weak self] in
            guard let self = self else { return }
            let messages = await MessageEngine.shared.getMessages()
            let unreadCount = await MessageEngine.shared.getUnreadCount()
            await MainActor.run {
                self.messagesRelay.accept(messages)
                self.unreadCountRelay.accept(unreadCount)
                self.applyFilters()
                self.reloadDataRelay.accept(())
            }
        }
    }

    private func applyFilters() {
        var messages = messagesRelay.value

        switch currentFilter {
        case .all:
            break
        case .unread:
            messages = messages.filter { !$0.isRead }
        case .today:
            let calendar = Calendar.current
            messages = messages.filter { calendar.isDateInToday($0.receivedAt) }
        }

        if !searchText.isEmpty {
            messages = messages.filter {
                $0.payload.title.localizedCaseInsensitiveContains(searchText) ||
                $0.payload.body.localizedCaseInsensitiveContains(searchText)
            }
        }

        let grouped = Dictionary(grouping: messages) { $0.payload.group ?? L10n.tr("inbox.group.ungrouped") }
        let groups = grouped.map { name, msgs in
            MessageGroup(
                name: name,
                messages: msgs.sorted { $0.receivedAt > $1.receivedAt }
            )
        }.sorted { $0.mostRecentDate > $1.mostRecentDate }

        messageGroupsRelay.accept(groups)
        isEmptyRelay.accept(messages.isEmpty)
    }

    private func markAsRead(id: String) {
        Task { [weak self] in
            await MessageEngine.shared.markAsRead(id: id)
            self?.loadMessages()
        }
    }

    private func sendTestMessage() {
        Task {
            let payload = MessagePayload(
                title: L10n.tr("inbox.test.title"),
                body: L10n.tr("inbox.test.body_format", DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)),
                channel: "test",
                group: L10n.tr("inbox.test.group")
            )
            try await MessageEngine.shared.receive(payload)
            loadMessages()
        }
    }
}
