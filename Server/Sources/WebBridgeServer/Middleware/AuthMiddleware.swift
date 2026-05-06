import HTTPTypes
import Hummingbird

struct AuthMiddleware<Context: RequestContext>: RouterMiddleware {
    let apiKey: String

    func handle(
        _ request: Request,
        context: Context,
        next: (Request, Context) async throws -> Response
    ) async throws -> Response {
        let path = request.uri.path
        guard isAdminEndpoint(path) else {
            return try await next(request, context)
        }
        guard request.method == .post || request.method == .put || request.method == .delete else {
            return try await next(request, context)
        }
        let providedKey = extractAPIKey(from: request)
        guard providedKey == apiKey else {
            throw HTTPError(.unauthorized, message: "Invalid or missing API key")
        }
        return try await next(request, context)
    }

    private func isAdminEndpoint(_ path: String) -> Bool {
        path.hasPrefix("/api/v1/manifests") && !path.hasSuffix("/version")
            || path.hasPrefix("/api/v1/stats")
    }

    private func extractAPIKey(from request: Request) -> String? {
        if let auth = request.headers[.authorization] {
            if auth.hasPrefix("Bearer ") {
                return String(auth.dropFirst(7))
            }
            return auth
        }
        if let query = request.uri.query {
            return query.split(separator: "&")
                .compactMap { param -> String? in
                    let parts = param.split(separator: "=", maxSplits: 1)
                    guard parts.count == 2, parts[0] == "apikey" else { return nil }
                    return String(parts[1])
                }
                .first
        }
        return nil
    }
}
