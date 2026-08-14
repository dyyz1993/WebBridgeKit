import Foundation

/// Bark push notification channel
/// Sends push notifications via Bark server (https://github.com/Finb/Bark)
public actor BarkChannel: @preconcurrency MessageChannel {
    public let channelId = "bark"
    public nonisolated(unsafe) var isActive = false

    private let serverURL: String
    private let key: String
    private let session: URLSession
    private var configuration: BarkConfiguration

    public init(
        serverURL: String = "https://api.day.app",
        key: String,
        configuration: BarkConfiguration = .default
    ) {
        self.serverURL = serverURL.hasSuffix("/") ? String(serverURL.dropLast()) : serverURL
        self.key = key
        self.configuration = configuration
        self.session = URLSession(configuration: .ephemeral)
    }

    public func start() async {
        isActive = true
    }

    public func stop() async {
        isActive = false
    }

    public func send(_ payload: MessagePayload) async throws -> MessageSendResult {
        guard isActive else {
            return .failed(error: .channelNotActive(channelId: channelId))
        }

        guard !key.isEmpty else {
            return .failed(error: .channelNotConfigured(channelId: channelId))
        }

        let url = try buildBarkURL(payload)

        do {
            let (_, response) = try await session.data(from: url)

            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200:
                    return .success(messageId: payload.id)
                case 401:
                    return .failed(error: .unauthorized)
                case 429:
                    let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                        .flatMap { TimeInterval($0) }
                    return .failed(error: .rateLimited(retryAfter: retryAfter))
                default:
                    return .failed(error: .serverError(
                        statusCode: httpResponse.statusCode,
                        message: "Unexpected status code"
                    ))
                }
            }

            return .success(messageId: payload.id)
        } catch {
            return .failed(error: .networkError(underlying: error))
        }
    }

    // MARK: - Bark API

    /// Send a simple text notification
    public func sendText(
        title: String,
        body: String,
        group: String? = nil,
        sound: String? = nil,
        url: String? = nil
    ) async throws -> MessageSendResult {
        let payload = MessagePayload(
            title: title,
            body: body,
            channel: channelId,
            sound: sound,
            group: group,
            targetURL: url
        )
        return try await send(payload)
    }

    /// Test connection to Bark server
    public func testConnection() async throws -> Bool {
        guard let url = URL(string: "\(serverURL)/\(key)/test/test") else {
            return false
        }

        let (_, response) = try await session.data(from: url)

        if let httpResponse = response as? HTTPURLResponse {
            return httpResponse.statusCode == 200
        }
        return false
    }

    // MARK: - Private Methods

    private func buildBarkURL(_ payload: MessagePayload) throws -> URL {
        var components: [String] = []

        // Base URL + key
        components.append(serverURL)
        components.append(key)

        // Title and body (URL encoded)
        let encodedTitle = payload.title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? payload.title
        let encodedBody = payload.body.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? payload.body

        components.append(encodedTitle)
        components.append(encodedBody)

        // Build URL string
        let urlString = components.joined(separator: "/")

        // Add query parameters
        var queryItems: [URLQueryItem] = []

        if let sound = payload.sound {
            queryItems.append(URLQueryItem(name: "sound", value: sound))
        }
        if let subtitle = payload.subtitle {
            queryItems.append(URLQueryItem(name: "subtitle", value: subtitle))
        }
        if let category = payload.category {
            queryItems.append(URLQueryItem(name: "category", value: category))
        }
        if let markdown = payload.markdown {
            queryItems.append(URLQueryItem(name: "markdown", value: markdown))
        }
        if let badge = payload.badge {
            queryItems.append(URLQueryItem(name: "badge", value: String(badge)))
        }
        if let group = payload.group {
            queryItems.append(URLQueryItem(name: "group", value: group))
        }
        if let threadID = payload.threadId {
            queryItems.append(URLQueryItem(name: "threadId", value: threadID))
        }
        if let url = payload.targetURL {
            queryItems.append(URLQueryItem(name: "url", value: url))
        }
        if let appID = payload.targetAppId {
            queryItems.append(URLQueryItem(name: "appid", value: appID))
        }
        if let route = payload.route {
            queryItems.append(URLQueryItem(name: "route", value: route))
        }
        if let mode = payload.targetMode {
            queryItems.append(URLQueryItem(name: "mode", value: mode))
        }
        if let level = payload.interruptionLevel?.rawValue ?? barkLevel(from: payload.priority) {
            queryItems.append(URLQueryItem(name: "level", value: level))
        }
        if let icon = payload.iconURL ?? configuration.icon {
            queryItems.append(URLQueryItem(name: "icon", value: icon))
        }
        if let image = payload.imageURL {
            queryItems.append(URLQueryItem(name: "image", value: image))
        }
        if payload.isArchive ?? configuration.isArchive {
            queryItems.append(URLQueryItem(name: "isArchive", value: "1"))
        }
        if let copyText = payload.copyText ?? payload.verificationCode {
            queryItems.append(URLQueryItem(name: "copy", value: copyText))
            if payload.isAutoCopy ?? configuration.copyable {
                queryItems.append(URLQueryItem(name: "autoCopy", value: "1"))
            }
        }
        if payload.isCall == true {
            queryItems.append(URLQueryItem(name: "call", value: "1"))
        }
        if let volume = payload.soundVolume {
            queryItems.append(URLQueryItem(name: "volume", value: String(volume)))
        }
        if let ttl = payload.ttl {
            queryItems.append(URLQueryItem(name: "ttl", value: String(Int(ttl))))
        }
        if let verificationCode = payload.verificationCode {
            queryItems.append(URLQueryItem(name: "verificationCode", value: verificationCode))
        }
        if let expiresAt = payload.expiresAt {
            queryItems.append(URLQueryItem(name: "expiresAt", value: ISO8601DateFormatter().string(from: expiresAt)))
        }
        if let replacementID = payload.replacementID {
            queryItems.append(URLQueryItem(name: "id", value: replacementID))
        }
        if payload.isDeleted == true {
            queryItems.append(URLQueryItem(name: "delete", value: "1"))
        }
        if let actionState = payload.actionState {
            queryItems.append(URLQueryItem(name: "actionState", value: actionState.rawValue))
        }
        if let requestID = payload.requestID {
            queryItems.append(URLQueryItem(name: "requestId", value: requestID))
        }
        if let contentType = payload.contentType {
            queryItems.append(URLQueryItem(name: "contentType", value: contentType.rawValue))
        }
        if let qrPayload = payload.qrPayload {
            queryItems.append(URLQueryItem(name: "qrPayload", value: qrPayload))
        }
        if let statePath = payload.statePath {
            queryItems.append(URLQueryItem(name: "statePath", value: statePath))
        }
        if let revision = payload.revision {
            queryItems.append(URLQueryItem(name: "revision", value: String(revision)))
        }

        var urlComponents = URLComponents(string: urlString)
        if !queryItems.isEmpty {
            urlComponents?.queryItems = queryItems
        }

        guard let url = urlComponents?.url else {
            throw MessageError.invalidPayload(reason: "Failed to build Bark URL")
        }

        return url
    }

    private func barkLevel(from priority: MessagePriority) -> String? {
        switch priority {
        case .critical:
            return "timeSensitive"
        case .high:
            return "active"
        case .normal:
            return nil  // Default
        case .low:
            return "passive"
        }
    }
}

/// Bark channel configuration
public struct BarkConfiguration: Sendable {
    public let icon: String?
    public let isArchive: Bool
    public let copyable: Bool
    public let maxRetries: Int
    public let timeout: TimeInterval

    public init(
        icon: String? = nil,
        isArchive: Bool = false,
        copyable: Bool = true,
        maxRetries: Int = 3,
        timeout: TimeInterval = 30
    ) {
        self.icon = icon
        self.isArchive = isArchive
        self.copyable = copyable
        self.maxRetries = maxRetries
        self.timeout = timeout
    }

    public static let `default` = BarkConfiguration()
}
