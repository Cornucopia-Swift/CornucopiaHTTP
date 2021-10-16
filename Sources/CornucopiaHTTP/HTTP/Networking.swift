//
//  Cornucopia – (C) Dr. Lauer Information Technology
//
import Foundation
import SWCompression

public class Networking: NSObject {
    
    /// To opt-out of compressing
    public static var enableCompressedUploads: Bool = true

    /// What can go wrong?
    public enum Error: Swift.Error {

        case unexpectedResponse(String)
        case unexpectedMimeType(String)
        case unsuccessful(HTTP.Status)
        case decodingError(Swift.Error)
    }

    public private(set) var urlSession: URLSession

    public override init() {
        self.urlSession = URLSession.shared
    }

    /// Issues a DELETE request for the identified resource.
    @discardableResult
    public func DELETE(via urlRequest: URLRequest) async throws -> HTTP.Status {
        try await self.trigger(urlRequest: urlRequest, method: .DELETE)
    }

    /// Issues a GET request, returning a `Decodable` resource.
    public func GET<DOWN: Decodable>(from urlRequest: URLRequest) async throws -> DOWN {
        try await self.download(urlRequest: urlRequest)
    }

    /// Issues a HEAD request, returning a set of headers.
    public func HEAD(at urlRequest: URLRequest) async throws -> HTTP.Headers {
        try await self.headers(urlRequest: urlRequest)
    }

    /// Issues a POST request with an `Encodable` resource and returns the created resource (of the same type).
    public func POST<UPDOWN: Codable>(item: UPDOWN, to urlRequest: URLRequest) async throws -> UPDOWN {
        try await self.updownload(item: item, urlRequest: urlRequest)
    }

    /// Issues a POST request with an `Encodable` resource and returns a `Decodable` resource of another type.
    public func POST<UP: Encodable, DOWN: Decodable>(item: UP, to urlRequest: URLRequest) async throws -> DOWN {
        try await self.updownload(item: item, urlRequest: urlRequest)
    }

    /// Issues a POST request with an `Encodable` resource and returns the status code, ignoring any further content received from the server.
    @discardableResult
    public func POST<UP: Codable>(item: UP, via urlRequest: URLRequest) async throws -> HTTP.Status {
        try await self.upload(item: item, urlRequest: urlRequest)
    }
}

internal extension Networking {

    func download<T: Decodable>(urlRequest: URLRequest) async throws -> T {

        let (data, response) = try await self.urlSession.data(for: urlRequest, delegate: nil)
        return try self.handleIncoming(data: data, response: response)
    }
    
    func trigger(urlRequest: URLRequest, method: HTTP.Method) async throws -> HTTP.Status {
        
        var urlRequest = urlRequest
        urlRequest.httpMethod = method.rawValue
        let (_, response) = try await self.urlSession.data(for: urlRequest, delegate: nil)
        return try self.handleResponse(response).status
    }

    func headers(urlRequest: URLRequest) async throws -> HTTP.Headers {
        
        var urlRequest = urlRequest
        urlRequest.httpMethod = HTTP.Method.HEAD.rawValue
        let (_, response) = try await self.urlSession.data(for: urlRequest, delegate: nil)
        return try self.handleResponse(response).headers
    }

    func upload<T: Encodable>(item: T, urlRequest: URLRequest, method: HTTP.Method = .POST) async throws -> HTTP.Status {

        var urlRequest = urlRequest
        urlRequest.httpMethod = method.rawValue
        let uploadData = try self.prepareUpload(item: item, in: &urlRequest)
        let (_, response) = try await self.urlSession.upload(for: urlRequest, from: uploadData, delegate: nil)
        return try self.handleResponse(response).status
    }

    func updownload<UP: Encodable, DOWN: Decodable>(item: UP, urlRequest: URLRequest, method: HTTP.Method = .POST) async throws -> DOWN {

        var urlRequest = urlRequest
        urlRequest.httpMethod = method.rawValue
        let uploadData = try self.prepareUpload(item: item, in: &urlRequest)
        let (data, response) = try await self.urlSession.upload(for: urlRequest, from: uploadData, delegate: nil)
        return try self.handleIncoming(data: data, response: response)
    }
}

private extension Networking {
    
    func prepareUpload<T: Encodable>(item: T, in urlRequest: inout URLRequest) throws -> Data {

        let uncompressed = try JSONEncoder().encode(item)
        urlRequest.setValue(HTTP.MimeType.applicationJSON.rawValue, forHTTPHeaderField: HTTP.HeaderField.contentType.rawValue)
        guard Self.enableCompressedUploads else { return uncompressed }
        do {
            let compressed = try GzipArchive.archive(data: uncompressed)
            guard compressed.count < uncompressed.count else { return uncompressed }
            urlRequest.addValue(HTTP.ContentEncoding.gzip.rawValue, forHTTPHeaderField: HTTP.HeaderField.contentEncoding.rawValue)
            return compressed
        } catch {
            //logger.notice("Can't compress: \(error), sending uncompressed")
        }
        return uncompressed
    }
    
    func handleIncoming<T: Decodable>(data: Data, response: URLResponse) throws -> T {
        
        guard let httpResponse = response as? HTTPURLResponse else { throw Error.unexpectedResponse("\(type(of: response)) != HTTPURLResponse") }
        let status = HTTP.Status(rawValue: httpResponse.statusCode) ?? .Unknown
        guard status.responseType == .Success else { throw Error.unsuccessful(status) }
        let mimeType = HTTP.MimeType(rawValue: response.mimeType ?? "unknown/unknown") ?? .unknown
        
        switch mimeType {
            case .applicationJSON:
                do {
                    let entity = try JSONDecoder().decode(T.self, from: data)
                    return entity
                } catch {
                    throw Error.decodingError(error)
                }
                
            default:
                throw Error.unexpectedMimeType(response.mimeType ?? "unknown/unknown")
        }
    }
    
    func handleResponse(_ response: URLResponse) throws -> HTTP.StatusAndHeaders {
        
        guard let httpResponse = response as? HTTPURLResponse else { throw Error.unexpectedResponse("\(type(of: response)) != HTTPURLResponse") }
        let status = HTTP.Status(rawValue: httpResponse.statusCode) ?? .Unknown
        guard status.responseType == .Success else { throw Error.unsuccessful(status) }
        let headers = httpResponse.allHeaderFields as? [String: String] ?? [:]
        return (status, headers)
    }
}
