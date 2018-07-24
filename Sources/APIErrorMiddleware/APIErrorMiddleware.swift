import Vapor
import Foundation

/// Catches errors thrown from route handlers or middleware
/// further down the responder chain and converts it to
/// a JSON response.
///
/// Errors with an identifier of `modelNotFound` get
/// a 404 status code.
public final class APIErrorMiddleware: Middleware, Service, ServiceType {
    
    /// Specializations for converting specific errors
    /// to `ErrorResult` objects.
    public var specializations: [ErrorCatchingSpecialization]
    
    /// The current environemnt that the application is in.
    public let environment: Environment
    
    /// Create an instance if `APIErrorMiddleware`.
    public init(environment: Environment, specializations: [ErrorCatchingSpecialization] = []) {
        self.specializations = specializations
        self.environment = environment
    }
    
    /// Creates a service instance. Used by a `ServiceFactory`.
    public static func makeService(for worker: Container) throws -> APIErrorMiddleware {
        #if canImport(Fluent)
            return APIErrorMiddleware(environment: worker.environment, specializations: [ModelNotFound()])
        #else
            return APIErrorMiddleware(environment: worker.environment, specializations: [])
        #endif
    }
    
    /// Catch all errors thrown by the route handler or
    /// middleware futher down the responder chain and
    /// convert it to a JSON response.
    public func respond(to request: Request, chainingTo next: Responder) throws -> Future<Response> {

        // Call the next responder in the reponse chain.
        // If the future returned contains an error, or if
        // the next responder throws an error, catch it and
        // convert it to a JSON response.
        return Future.flatMap(on: request) {
            return try next.respond(to: request)
        }.mapIfError { error in
            return self.response(for: error, with: request)
        }
    }
    
    /// Creates a response with a JSON body.
    ///
    /// - Parameters:
    ///   - error: The error that will be the value of the
    ///     `error` key in the responses JSON body.
    ///   - request: The request we wil get a container from
    ///     to create the resulting reponse in.
    ///
    /// - Returns: A response with a JSON body with a `{"error":<error>}` structure.
    private func response(for error: Error, with request: Request) -> Response {
        
        // The error message and status code
        // for the response returned by the
        // middleware.
        var result: ErrorResult!

        // The HTTP headers to send with the error
        var headers: HTTPHeaders = ["Content-Type": "application/json"]

        
        // Loop through the specializations, running
        // the error converter on each one.
        for converter in self.specializations {
            if let formatted = converter.convert(error: error, on: request) {
                
                // Found a non-nil response. Save it and break
                // from the loop so we don't override it.
                result = formatted
                break
            }
        }
        
        if result == nil {
            switch error {
            case let abort as AbortError:
                // We have an `AbortError` which has both a
                // status code and error message.
                // Assign the data to the correct varaibles.
                result = ErrorResult(message: abort.reason, status: abort.status)

                abort.headers.forEach { name, value in
                    headers.add(name: name, value: value)
                }
            case let debuggable as Debuggable where !self.environment.isRelease:
                // Since we are not in a production environment and we
                // have a error conforming to `Debuggable`, we get the
                // data about the error and create a result with it.
                // We don't do this in a production env because the error
                // might container sensetive information
                let reason = debuggable.debuggableHelp(format: .short)
                result = ErrorResult(message: reason, status: .internalServerError)
            default:
                // We use a compiler OS check because `Error` can be directly
                // convertred to `CustomStringConvertible` on macOS, but not
                // on Linux.
                #if !os(macOS)
                if let error = error as? CustomStringConvertible {
                    result = ErrorResult(message: error.description, status: nil)
                } else {
                    result = ErrorResult(message: "Unknown error.", status: nil)
                }
                #else
                result = ErrorResult(message: (error as CustomStringConvertible).description, status: nil)
                #endif
            }
        }
        
        let json: Data
        do {
            // Create JSON with an `error` key with the `message` constant as its value.
            json = try JSONEncoder().encode(["error": result.message])
        } catch {
            // Creating JSON data from error failed, so create a generic response message
            // because we can't have any Swift errors leaving the middleware.
            json = Data("{\"error\": \"Unable to encode error to JSON\"}".utf8)
        }
        
        // Create an HTTPResponse with
        // - The detected status code, using
        //   400 (Bad Request) if one does not exist.
        // - A `application/json` Content Type header.
        // A body with the JSON we created.
        let httpResponse = HTTPResponse(
            status: result.status ?? .badRequest,
            headers: headers,
            body: HTTPBody(data: json)
        )
        
        // Create the response and return it.
        return Response(http: httpResponse, using: request.sharedContainer)
    }
}
