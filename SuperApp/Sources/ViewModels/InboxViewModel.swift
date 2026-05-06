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

        var unreadCount: Int {
            messages.filter { !$0.isRead }.count
        }
    }

    private let messagesRelay = BehaviorRelay<[StoredMessage]>(value: [])
    private let messageGroupsRelay = BehaviorRelay<[MessageGroup]>(value: [])
    private let isEmptyRelay = BehaviorRelay<Bool>(value: true)
    private let selectedMessageRelay = PublishRelay<StoredMessage>()
    private let unreadCountRelay = BehaviorRelay<Int>(value: 0)

    private var searchText: String = ""
    private var currentFilter: FilterType = .all

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
                self?.searchText = text
                self?.applyFilters()
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
                var offset = 0
                for group in groups {
                    if group.isExpanded {
                        if indexPath.row >= offset && indexPath.row < offset + group.messages.count {
                            return group.messages[indexPath.row - offset]
                        }
                        offset += group.messages.count
                    }
                }
                return nil
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
            unreadCount: unreadCountRelay.asDriver()
        )
    }

    func refreshData() {
        loadMessages()
    }

    func messageAt(_ indexPath: IndexPath) -> StoredMessage {
        var offset = 0
        for group in messageGroupsRelay.value {
            if group.isExpanded {
                if indexPath.row >= offset && indexPath.row < offset + group.messages.count {
                    return group.messages[indexPath.row - offset]
                }
                offset += group.messages.count
            }
        }
        fatalError("Index out of bounds")
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
        return "\(group.name) (\(group.messages.count))" + (unread > 0 ? " · \(unread)未读" : "")
    }

    func numberOfRowsInGroup(_ index: Int) -> Int {
        guard index < messageGroupsRelay.value.count else { return 0 }
        return messageGroupsRelay.value[index].isExpanded ? messageGroupsRelay.value[index].messages.count : 0
    }

    func messageIndexPath(globalRow row: Int) -> (group: Int, localRow: Int)? {
        var offset = 0
        for (gi, group) in messageGroupsRelay.value.enumerated() {
            if group.isExpanded {
                if row >= offset && row < offset + group.messages.count {
                    return (gi, row - offset)
                }
                offset += group.messages.count
            }
        }
        return nil
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

        let grouped = Dictionary(grouping: messages) { $0.payload.group ?? "未分组" }
        let groups = grouped.map { name, msgs in
            MessageGroup(
                name: name,
                messages: msgs.sorted { $0.receivedAt > $1.receivedAt }
            )
        }.sorted { $0.name < $1.name }

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
                title: "测试通知",
                body: "这是一条测试消息，发送于 \(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium))",
                channel: "test",
                group: "测试消息"
            )
            try await MessageEngine.shared.receive(payload)
            loadMessages()
        }
    }
}
