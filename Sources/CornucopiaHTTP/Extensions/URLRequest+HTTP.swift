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
    
    /// Issues a HTTP POST request with a binary resource and returns the status code – ignoring any further content received from the server.
    @discardableResult
    public func POST(data: Data) async throws -> HTTP.Status {
        try await Networking().self.binaryUpload(data: data, urlRequest: self)
    }

    /// Issues a HTTP POST request with multipart data and returns the status code.
    @discardableResult
    public func POST(multipart parts: [Networking.MultipartPart]) async throws -> HTTP.Status {
        try await Networking().self.POST(multipart: parts, via: self)
    }

    /// Issues a HTTP POST request with multipart data and returns a `Decodable` response.
    public func POST<DOWN: Decodable>(multipart parts: [Networking.MultipartPart]) async throws -> DOWN {
        try await Networking().self.POST(multipart: parts, to: self)
    }

    /// Issues a HTTP POST request with a JSON payload and a binary attachment.
    @discardableResult
    public func POST<UP: Encodable>(
        json: UP,
        binary: Data,
        jsonFieldName: String = "json",
        binaryFieldName: String = "file",
        binaryFilename: String = "file.bin",
        binaryMimeType: HTTP.MimeType = .applicationOctetStream
    ) async throws -> HTTP.Status {
        try await Networking().self.POST(
            json: json,
            binary: binary,
            via: self,
            jsonFieldName: jsonFieldName,
            binaryFieldName: binaryFieldName,
            binaryFilename: binaryFilename,
            binaryMimeType: binaryMimeType
        )
    }

    /// Issues a HTTP PUT request with an `Codable` resource and returns the created resource (of the same type).
    public func PUT<UPDOWN: Codable>(item: UPDOWN) async throws -> UPDOWN {
        try await Networking().self.updownload(item: item, urlRequest: self, method: .PUT)
    }
}
