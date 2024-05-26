//
//  Cornucopia – (C) Dr. Lauer Information Technology
//
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// HTTP Convenience wrappers.
@frozen public enum HTTP {

    /// Issues a HTTP DELETE request for the identified resource.
    @discardableResult
    public static func DELETE(via urlRequest: URLRequest) async throws -> HTTP.Status {
        try await Networking().self.trigger(urlRequest: urlRequest, method: .DELETE)
    }

    /// Issues a HTTP GET request, returning a `Decodable` resource.
    public static func GET<DOWN: Decodable>(from urlRequest: URLRequest) async throws -> DOWN {
        try await Networking().self.download(urlRequest: urlRequest)
    }
    
    /// Issues a HTTP GET request, writing the result to the (file url) `destinationURL`.
    public static func GET(from urlRequest: URLRequest, to destinationURL: URL) async throws -> HTTP.Headers {
        try await Networking().self.load(urlRequest: urlRequest, to: destinationURL)
    }

    /// Issues a HTTP GET request, writing the result to the (file url) `destinationURL`.
    public static func GET(from urlRequest: URLRequest, to destinationURL: URL, observeProgress: Networking.ProgressObserver) async throws -> HTTP.Headers {
        try await Networking().self.load(urlRequest: urlRequest, to: destinationURL)
    }

    /// Issues a HTTP HEAD request, returning a set of headers.
    public static func HEAD(at urlRequest: URLRequest) async throws -> HTTP.Headers {
        try await Networking().self.headers(urlRequest: urlRequest)
    }

    /// Issues a HTTP PATCH request with an `Codable` resource and returns the created resource (of the same type).
    public static func PATCH<UPDOWN: Codable>(item: UPDOWN, to urlRequest: URLRequest) async throws -> UPDOWN {
        try await Networking().self.updownload(item: item, urlRequest: urlRequest, method: .PATCH)
    }

    /// Issues a HTTP PATCH request with an `Encodable` resource and returns a `Decodable` resource of (possibly) another type.
    public static func PATCH<UP: Encodable, DOWN: Decodable>(item: UP, to urlRequest: URLRequest) async throws -> DOWN {
        try await Networking().self.updownload(item: item, urlRequest: urlRequest, method: .PATCH)
    }

    /// Issues a HTTP POST request with an `Codable` resource and returns the created resource (of the same type).
    public static func POST<UPDOWN: Codable>(item: UPDOWN, to urlRequest: URLRequest) async throws -> UPDOWN {
        try await Networking().self.updownload(item: item, urlRequest: urlRequest)
    }

    /// Issues a HTTP POST request with an `Encodable` resource and returns a `Decodable` resource of (possibly) another type.
    public static func POST<UP: Encodable, DOWN: Decodable>(item: UP, to urlRequest: URLRequest) async throws -> DOWN {
        try await Networking().self.updownload(item: item, urlRequest: urlRequest)
    }

    /// Issues a HTTP POST request with an `Encodable` resource and returns the status code – ignoring any further content received from the server.
    @discardableResult
    public static func POST<UP: Encodable>(item: UP, via urlRequest: URLRequest) async throws -> HTTP.Status {
        try await Networking().self.upload(item: item, urlRequest: urlRequest)
    }

    /// Issues a HTTP POST request with a binary resource and returns the status code ­– ignoring any further content received from the server.
    @discardableResult
    public static func POST(data: Data, via urlRequest: URLRequest) async throws -> HTTP.Status {
        try await Networking().self.binaryUpload(data: data, urlRequest: urlRequest)
    }

    /// Issues a HTTP PUT request with a `Codable` resource and returns the created resource (of the same type).
    public static func PUT<UPDOWN: Codable>(item: UPDOWN, to urlRequest: URLRequest) async throws -> UPDOWN {
        try await Networking().self.updownload(item: item, urlRequest: urlRequest, method: .PUT)
    }
}
