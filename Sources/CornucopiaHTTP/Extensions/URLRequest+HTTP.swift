//
//  Cornucopia – (C) Dr. Lauer Information Technology
//
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Convenience wrappers for issuing HTTP methods directly on URL requests
extension URLRequest {
    
    /// Issues a HTTP DELETE request for the identified resource.
    @discardableResult
    public func DELETE() async throws -> HTTP.Status {
        try await Networking().self.trigger(urlRequest: self, method: .DELETE)
    }

    /// Issues a HTTP GET request, returning a `Decodable` resource.
    public func GET<DOWN: Decodable>() async throws -> DOWN {
        try await Networking().self.download(urlRequest: self)
    }
    
    /// Issues a HTTP GET request, saving returned data to a file.
    @discardableResult
    public func GET(to destinationURL: URL) async throws -> HTTP.Headers {
        try await Networking().self.load(urlRequest: self, to: destinationURL)
    }
    
    /// Issues a HTTP HEAD request, returning a set of headers.
    public func HEAD() async throws -> HTTP.Headers {
        try await Networking().self.headers(urlRequest: self)
    }
    
    /// Issues a HTTP PATCH request with an `Codable` resource and returns the created resource (of the same type).
    public func PATCH<UPDOWN: Codable>(item: UPDOWN) async throws -> UPDOWN {
        try await Networking().self.updownload(item: item, urlRequest: self, method: .PATCH)
    }
    
    /// Issues a HTTP PATCH request with an `Encodable` resource and returns a `Decodable` resource of (possibly) another type.
    public func PATCH<UP: Encodable, DOWN: Decodable>(item: UP) async throws -> DOWN {
        try await Networking().self.updownload(item: item, urlRequest: self, method: .PATCH)
    }

    /// Issues a HTTP POST request with an `Codable` resource and returns the created resource (of the same type).
    public func POST<UPDOWN: Codable>(item: UPDOWN) async throws -> UPDOWN {
        try await Networking().self.updownload(item: item, urlRequest: self)
    }
    
    /// Issues a HTTP POST request with an `Encodable` resource and returns a `Decodable` resource of (possibly) another type.
    public func POST<UP: Encodable, DOWN: Decodable>(item: UP) async throws -> DOWN {
        try await Networking().self.updownload(item: item, urlRequest: self)
    }
    
    /// Issues a HTTP POST request with an `Encodable` resource and returns the status code – ignoring any further content received from the server.
    @discardableResult
    public func POST<UP: Encodable>(item: UP) async throws -> HTTP.Status {
        try await Networking().self.upload(item: item, urlRequest: self)
    }
    
    /// Issues a HTTP PUT request with an `Codable` resource and returns the created resource (of the same type).
    public func PUT<UPDOWN: Codable>(item: UPDOWN) async throws -> UPDOWN {
        try await Networking().self.updownload(item: item, urlRequest: self, method: .PUT)
    }
}
