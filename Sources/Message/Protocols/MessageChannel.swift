import Foundation

/// Message channel protocol - defines how messages are received
public protocol MessageChannel: AnyObject, Sendable {
    /// Channel identifier
    var channelId: String { get }

    /// Whether the channel is active
    var isActive: Bool { get }

    /// Start listening for messages
    func start() async

    /// Stop listening for messages
    func stop() async

    /// Send a message through this channel
    func send(_ payload: MessagePayload) async throws -> MessageSendResult
}

/// Message payload - unified message format
public struct MessagePayload: Codable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let body: String
    public let markdown: String?
    public let subtitle: String?
    public let channel: String
    public let category: String?
    public let priority: MessagePriority
    public let sound: String?
    public let badge: Int?
    public let group: String?
    public let threadId: String?
    public let targetURL: String?
    public let targetAppId: String?
    /// Validated internal path for a registered HTML app. Dynamic parameters stay in userInfo.
    public let route: String?
    public let targetMode: String?
    public let verificationCode: String?
    public let expiresAt: Date?
    public let imageURL: String?
    public let iconURL: String?
    public let interruptionLevel: MessageInterruptionLevel?
    public let soundVolume: Double?
    public let isCall: Bool?
    public let copyText: String?
    public let isAutoCopy: Bool?
    public let isArchive: Bool?
    public let ttl: TimeInterval?
    public let replacementID: String?
    public let isDeleted: Bool?
    /// Lifecycle of a remote action. Only `pending` is considered actionable.
    public let actionState: MessageActionState?
    /// Stable request identity shared by the notification and the target PWA.
    public let requestID: String?
    /// Explicit rendering hint. Unknown values safely fall back to plain text.
    public let contentType: MessageContentType?
    /// Text encoded as a QR code by the native detail screen.
    public let qrPayload: String?
    /// Optional PWA-owned endpoint/path used by the opened app to refresh state.
    public let statePath: String?
    /// Monotonic revision used to ignore out-of-order state updates.
    public let revision: Int?
    /// Approval v1 rendering mode. Common routing fields remain top-level.
    public let presentation: MessagePresentation?
    /// Native approval-only fields. Server-only callback configuration is never delivered here.
    public let approval: MessageApproval?
    public let userInfo: [String: String]?
    public let createdAt: Date

    public init(
        id: String = UUID().uuidString,
        title: String,
        body: String,
        markdown: String? = nil,
        subtitle: String? = nil,
        channel: String,
        category: String? = nil,
        priority: MessagePriority = .normal,
        sound: String? = nil,
        badge: Int? = nil,
        group: String? = nil,
        threadId: String? = nil,
        targetURL: String? = nil,
        targetAppId: String? = nil,
        route: String? = nil,
        targetMode: String? = nil,
        verificationCode: String? = nil,
        expiresAt: Date? = nil,
        imageURL: String? = nil,
        iconURL: String? = nil,
        interruptionLevel: MessageInterruptionLevel? = nil,
        soundVolume: Double? = nil,
        isCall: Bool? = nil,
        copyText: String? = nil,
        isAutoCopy: Bool? = nil,
        isArchive: Bool? = nil,
        ttl: TimeInterval? = nil,
        replacementID: String? = nil,
        isDeleted: Bool? = nil,
        actionState: MessageActionState? = nil,
        requestID: String? = nil,
        contentType: MessageContentType? = nil,
        qrPayload: String? = nil,
        statePath: String? = nil,
        revision: Int? = nil,
        presentation: MessagePresentation? = nil,
        approval: MessageApproval? = nil,
        userInfo: [String: String]? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.markdown = markdown
        self.subtitle = subtitle
        self.channel = channel
        self.category = category
        self.priority = priority
        self.sound = sound
        self.badge = badge
        self.group = group
        self.threadId = threadId
        self.targetURL = targetURL
        self.targetAppId = targetAppId
        self.route = route
        self.targetMode = targetMode
        self.verificationCode = verificationCode
        self.expiresAt = expiresAt
        self.imageURL = imageURL
        self.iconURL = iconURL
        self.interruptionLevel = interruptionLevel
        self.soundVolume = soundVolume
        self.isCall = isCall
        self.copyText = copyText
        self.isAutoCopy = isAutoCopy
        self.isArchive = isArchive
        self.ttl = ttl
        self.replacementID = replacementID
        self.isDeleted = isDeleted
        self.actionState = actionState
        self.requestID = requestID
        self.contentType = contentType
        self.qrPayload = qrPayload
        self.statePath = statePath
        self.revision = revision
        self.presentation = presentation
        self.approval = approval
        self.userInfo = userInfo
        self.createdAt = createdAt
    }

    /// Whether this message has a routing target
    public var hasRoute: Bool {
        targetURL != nil || targetAppId != nil
    }

    public var expirationDate: Date? {
        expiresAt ?? ttl.map { createdAt.addingTimeInterval($0) }
    }

    public var isVerificationMessage: Bool {
        guard let category = category?.lowercased() else {
            return verificationCode?.isEmpty == false
        }
        return verificationCode?.isEmpty == false || category == "verification" || category == "otp"
    }

    public var isExpired: Bool {
        guard let expirationDate else { return false }
        return expirationDate <= Date()
    }

    /// A notification is actionable only when the sender explicitly says it is
    /// pending and the request has not expired. Category/priority alone never
    /// grants action semantics.
    public var requiresUserAction: Bool {
        actionState == .pending && !isExpired
    }

    /// Identity used for remote updates and withdrawals.
    public var updateIdentity: String {
        replacementID ?? requestID ?? id
    }

    public var hasNativeApprovalActions: Bool {
        contentType == .approval
            && presentation == .native
            && actionState == .pending
            && !isExpired
            && approval?.actions.isEmpty == false
    }

    /// Returns the same message envelope with a newer server-authoritative action state.
    /// Keeping the replacement identity intact lets MessageEngine update the existing row.
    public func updatingActionState(_ state: MessageActionState, revision: Int) -> MessagePayload {
        MessagePayload(
            id: id,
            title: title,
            body: body,
            markdown: markdown,
            subtitle: subtitle,
            channel: channel,
            category: category,
            priority: priority,
            sound: sound,
            badge: badge,
            group: group,
            threadId: threadId,
            targetURL: targetURL,
            targetAppId: targetAppId,
            route: route,
            targetMode: targetMode,
            verificationCode: verificationCode,
            expiresAt: expiresAt,
            imageURL: imageURL,
            iconURL: iconURL,
            interruptionLevel: interruptionLevel,
            soundVolume: soundVolume,
            isCall: isCall,
            copyText: copyText,
            isAutoCopy: isAutoCopy,
            isArchive: isArchive,
            ttl: ttl,
            replacementID: replacementID,
            isDeleted: isDeleted,
            actionState: state,
            requestID: requestID,
            contentType: contentType,
            qrPayload: qrPayload,
            statePath: statePath,
            revision: revision,
            presentation: presentation,
            approval: approval,
            userInfo: userInfo,
            createdAt: createdAt
        )
    }
}

public enum MessagePresentation: String, Codable, Sendable, CaseIterable {
    case native
    case web
    case pwa
}

public enum MessageApprovalActionStyle: String, Codable, Sendable {
    case primary
    case `default`
    case destructive
}

public struct MessageApprovalAction: Codable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let style: MessageApprovalActionStyle?
    public let requiresReason: Bool?
    public let resultState: MessageActionState?

    public init(
        id: String,
        title: String,
        style: MessageApprovalActionStyle? = nil,
        requiresReason: Bool? = nil,
        resultState: MessageActionState? = nil
    ) {
        self.id = id
        self.title = title
        self.style = style
        self.requiresReason = requiresReason
        self.resultState = resultState
    }
}

public struct MessageApproval: Codable, Sendable, Equatable {
    public let actions: [MessageApprovalAction]

    public init(actions: [MessageApprovalAction]) {
        self.actions = actions
    }
}

public enum MessageActionState: String, Codable, Sendable, CaseIterable {
    case pending
    case approved
    case rejected
    case cancelled
    case expired
}

public enum MessageContentType: String, Codable, Sendable, CaseIterable {
    case plain
    case markdown
    case image
    case qr
    case approval
    case otp
    case chat
}

/// Message priority levels
public enum MessagePriority: String, Codable, Sendable, CaseIterable {
    case low
    case normal
    case high
    case critical

    public var intValue: Int {
        switch self {
        case .low: return 0
        case .normal: return 5
        case .high: return 8
        case .critical: return 10
        }
    }
}

/// Message send result
public enum MessageSendResult: Sendable {
    case success(messageId: String)
    case failed(error: MessageError)
    case queued(messageId: String)
}

/// Message errors
public enum MessageError: Error, Sendable, LocalizedError {
    case channelNotActive(channelId: String)
    case channelNotConfigured(channelId: String)
    case invalidPayload(reason: String)
    case sendFailed(reason: String)
    case networkError(underlying: Error)
    case unauthorized
    case rateLimited(retryAfter: TimeInterval?)
    case serverError(statusCode: Int, message: String)

    public var errorDescription: String? {
        switch self {
        case .channelNotActive(let id):
            return "Channel '\(id)' is not active"
        case .channelNotConfigured(let id):
            return "Channel '\(id)' is not configured"
        case .invalidPayload(let reason):
            return "Invalid payload: \(reason)"
        case .sendFailed(let reason):
            return "Send failed: \(reason)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unauthorized:
            return "Unauthorized - check API key"
        case .rateLimited(let retryAfter):
            if let retryAfter = retryAfter {
                return "Rate limited - retry after \(retryAfter) seconds"
            }
            return "Rate limited"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        }
    }
}
