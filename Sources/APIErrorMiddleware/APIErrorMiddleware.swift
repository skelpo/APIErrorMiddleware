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
    let specializations: [ErrorCatchingSpecialization]
    
    /// Create an instance if `APIErrorMiddleware`.
    public init(specializations: [ErrorCatchingSpecialization] = []) {
        self.specializations = specializations
    }
    
    /// Creates a service instance. Used by a `ServiceFactory`.
    public static func makeService(for worker: Container) throws -> APIErrorMiddleware {
        return APIErrorMiddleware()
    }
    
    /// Catch all errors thrown by the route handler or
    /// middleware futher down the responder chain and
    /// convert it to a JSON response.
    public func respond(to request: Request, chainingTo next: Responder) throws -> Future<Response> {
        
        // We create a new promise that wraps a `Response` object.
        // No, there are not any initializers to do this.
        let result = request.eventLoop.newPromise(Response.self)
        
        // Call the next responder in the reponse chain.
        // If the future returned contains an error, or if
        // the next responder throws an error, catch it and
        // convert it to a JSON response.
        // If no error is found, succed the promise with the response
        // returned by the responder.
        do {
            try next.respond(to: request).do { response in
                result.succeed(result: response)
            }.catch { error in
                result.succeed(result: self.response(for: error, with: request))
            }
        } catch {
            result.succeed(result: self.response(for: error, with: request))
        }
        
        return result.futureResult
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
        
        if result == nil, let error = error as? AbortError {
            
            // We have an `AbortError` which has both a
            // status code and error message.
            // Assign the data to the correct varaibles.
            result = ErrorResult(message: error.reason, status: error.status)
        } else if result == nil {
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
        
        // Create JSON with an `error` key with the `message` constant as its value.
        // We default to no data instead of throwing, because we don't want any errors
        // leaving the middleware body.
        let json = (try? JSONEncoder().encode(["error": result.message])) ?? result.message.data(using: .utf8) ?? Data()
        
        // Create an HTTPResponse with
        // - The detected status code, using
        //   400 (Bad Request) if one does not exist.
        // - A `application/json` Content Type header.
        // A body with the JSON we created.
        let httpResponse = HTTPResponse(
            status: result.status ?? .badRequest,
            headers: ["Content-Type": "application/json"],
            body: HTTPBody(data: json)
        )
        
        // Create the response and return it.
        return Response(http: httpResponse, using: request.sharedContainer)
    }
}
