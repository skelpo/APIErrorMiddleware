import Vapor

/// The data used to create a response
/// from a Swift error.
public struct ErrorResult {
    
    /// The value of the 'error' key in
    /// the JSON returned by the middleware.
    public let message: String
    
    /// The status code for the response
    /// returned by the middleware
    public let status: HTTPStatus?
    
    /// Creates an instance with a 'message' and 'status'.
    public init(message: String, status: HTTPStatus?) {
        self.message = message
        self.status = status
    }
}

/// Converts a Swift error, along with data from a request,
/// to a `ErroResult` instance, which can be used to create
/// a JSON response
public protocol ErrorCatchingSpecialization {
    
    /// Converts a Swift error, along with data from a request,
    /// to a `ErroResult` instance, which can be used to create
    /// a JSON response
    ///
    /// - Parameters:
    ///   - error: The error to convert to a message.
    ///   - request: The request that the error originated from.
    ///
    /// - Returns: An `ErrorResult` instance. The result should be `nil`
    ///   if the specialization doesn't convert the kind of the error
    ///   passed in.
    func convert(error: Error, on request: Request) -> ErrorResult?
}

// MARK: - ErrorCatchingSpecialization implementations

#if canImport(Fluent)
import Fluent

/// Catches Fluent's `modelNotFound` error and returns a 404 status code.
public struct ModelNotFound: ErrorCatchingSpecialization {
    public init() {}

    public func convert(error: Error, on request: Request) -> ErrorResult? {
        if
            let wrappingError = error as? NotFound,
            let error = wrappingError.rootCause as? FluentError
        {
            return ErrorResult(message: error.reason, status: .notFound)
        }

        return nil
    }
}
#endif
