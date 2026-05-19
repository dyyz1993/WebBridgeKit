import HTTPTypes
import Hummingbird
import NIOCore

struct CORSWhitelistMiddleware<Context: RequestContext>: RouterMiddleware {
    let allowedOrigins: Set<String>
    let allowHeaders: String
    let allowMethods: String
    let maxAge: String?

    init(
        allowedOrigins: [String],
        allowHeaders: [HTTPField.Name] = [.accept, .authorization, .contentType, .origin],
        allowMethods: [HTTPRequest.Method] = [.get, .post, .put, .delete, .head, .options, .patch],
        maxAge: TimeAmount? = nil
    ) {
        self.allowedOrigins = Set(allowedOrigins)
        self.allowHeaders = allowHeaders.map(\.canonicalName).joined(separator: ", ")
        self.allowMethods = allowMethods.map(\.rawValue).joined(separator: ", ")
        self.maxAge = maxAge.map { String($0.nanoseconds / 1_000_000_000) }
    }

    func handle(
        _ request: Request, context: Context,
        next: (Request, Context) async throws -> Response
    ) async throws -> Response {
        guard request.headers.contains(.origin) else {
            return try await next(request, context)
        }

        guard let origin = request.headers[.origin], !origin.isEmpty, origin != "null" else {
            return try await next(request, context)
        }
        let isAllowed = allowedOrigins.contains(origin)

        if request.method == .options {
            guard isAllowed else {
                return Response(status: .noContent, body: .init())
            }
            var headers: HTTPFields = [
                .accessControlAllowHeaders: self.allowHeaders,
                .accessControlAllowMethods: self.allowMethods,
                .accessControlAllowOrigin: origin,
                .vary: "Origin",
            ]
            if let maxAge = self.maxAge {
                headers[.accessControlMaxAge] = maxAge
            }
            return Response(status: .noContent, headers: headers, body: .init())
        } else {
            var response = try await next(request, context)
            if isAllowed {
                response.headers[.accessControlAllowOrigin] = origin
                response.headers[.vary] = "Origin"
            }
            return response
        }
    }
}
