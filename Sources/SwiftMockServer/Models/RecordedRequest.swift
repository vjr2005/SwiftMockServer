// RecordedRequest.swift
// SwiftMockServer

import Foundation

/// A recorded incoming request with its timestamp and matched route.
///
/// Every request received by the server is recorded and accessible via
/// ``MockServer/requests``, ``MockServer/requests(matching:)``,
/// ``MockServer/requests(method:path:)``, or ``MockServer/waitForRequest(method:path:timeout:pollInterval:)``.
///
/// ```swift
/// // After making requests to the server...
/// let recorded = await server.requests(method: .POST, path: "/api/users")
/// XCTAssertEqual(recorded.count, 1)
///
/// let body = try recorded[0].request.jsonBody(CreateUser.self)
/// XCTAssertEqual(body.name, "Alice")
/// ```
public struct RecordedRequest: Sendable {
    /// The parsed HTTP request.
    public let request: MockHTTPRequest

    /// When the request was received.
    public let timestamp: Date

    /// A description of the route that handled this request, or `nil` if no route matched
    /// (i.e., the default response was returned).
    public let matchedRoute: String?

    /// Create a recorded request.
    ///
    /// Normally you don't create these directly — the server records them automatically.
    ///
    /// - Parameters:
    ///   - request: The parsed HTTP request.
    ///   - timestamp: When the request was received. Defaults to now.
    ///   - matchedRoute: Description of the matched route, or `nil`.
    public init(request: MockHTTPRequest, timestamp: Date = Date(), matchedRoute: String? = nil) {
        self.request = request
        self.timestamp = timestamp
        self.matchedRoute = matchedRoute
    }
}
