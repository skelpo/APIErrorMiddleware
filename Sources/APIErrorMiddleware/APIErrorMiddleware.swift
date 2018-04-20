import Vapor
import Foundation

public final class APIErrorMiddleware: Middleware {
    public init() {}
    
    public func respond(to request: Request, chainingTo next: Responder) throws -> Future<Response> {
        let result = request.eventLoop.newPromise(Response.self)
        
        do {
            return try next.respond(to: request).do({ (response) in
                result.succeed(result: response)
            }).catch({ (error) in
                result.succeed(result: self.response(for: error, with: request))
            })
        } catch {
            result.succeed(result: self.response(for: error, with: request))
        }
        
        return result.futureResult
    }
    
    private func response(for error: Error, with request: Request) -> Response {
        let message: String
        let status: HTTPStatus?
        
        if let error = error as? AbortError {
            message = error.reason
            status = error.status
        } else {
            let error = error as CustomStringConvertible
            message = error.description
            status = nil
        }
        
        let json = (try? JSONEncoder().encode(["error": message])) ?? message.data(using: .utf8) ?? Data()
        let httpResponse = HTTPResponse(
            status: status ?? .badRequest,
            headers: ["Content-Type": "application/json"],
            body: HTTPBody(data: json)
        )
        
        return Response(http: httpResponse, using: request.sharedContainer)
    }
}
