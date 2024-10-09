//
//  Cornucopia – (C) Dr. Lauer Information Technology
//
import CornucopiaCore
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(FoundationBandAid)
import FoundationBandAid
#endif
import SWCompression

public final class Networking: NSObject {

    /// To use a custom URLSession
    public static var customURLSession: URLSession?

    /// A configurable busy provider
    public static var busynessObserver: (any Cornucopia.Core.BusynessObserver)? = nil

    /// What can go wrong?
    @frozen public enum Error: Swift.Error {

        case unsuitableRequest(String)
        case unexpectedResponse(String)
        case unexpectedMimeType(String)
        case unsuccessful(HTTP.Status)
        case decodingError(Swift.Error)
        case unsuccessfulWithDetails(HTTP.Status, details: [String: AnyDecodable])
    }

    /// To observe progress
    public typealias ProgressObserver = (Progress) -> ()

    /// The current `URLsession`
    public let urlSession: URLSession

    public override init() {
        self.urlSession = Self.customURLSession ?? URLSession.shared
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
    
    /// Issues a GET request, writing the output to a file.
    public func GET(from urlRequest: URLRequest, to destinationURL: URL) async throws -> HTTP.Headers {
        try await self.load(urlRequest: urlRequest, to: destinationURL)
    }

    /// Issues a GET request, writing the output to a file, observing download progress.
    public func GET(from urlRequest: URLRequest, to destinationURL: URL, progressObserver: @escaping(Networking.ProgressObserver)) async throws -> HTTP.Headers {
        try await self.load(urlRequest: urlRequest, to: destinationURL, progressObserver: progressObserver)
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

    /// Issues a POST request with a binary resource and returns the status code, ignoring any further content received from the server.
    @discardableResult
    public func POST(data: Data, via urlRequest: URLRequest) async throws -> HTTP.Status {
        try await self.binaryUpload(data: data, urlRequest: urlRequest)
    }
}

internal extension Networking {

    func download<T: Decodable>(urlRequest: URLRequest) async throws -> T {
        
        if let mock = Self.mock(for: urlRequest) { return try Self.handleIncoming(data: mock.data, response: mock.response) }
        if let busynessObserver = Self.busynessObserver { busynessObserver.enterBusy() }
        defer { if let busynessObserver = Self.busynessObserver { busynessObserver.leaveBusy() } }
        let (data, response) = try await self.urlSession.data(for: urlRequest, delegate: nil)
        return try Self.handleIncoming(data: data, response: response)
    }
    
    func trigger(urlRequest: URLRequest, method: HTTP.Method) async throws -> HTTP.Status {
        
        var urlRequest = urlRequest
        urlRequest.httpMethod = method.rawValue
        if let busynessObserver = Self.busynessObserver { busynessObserver.enterBusy() }
        defer { if let busynessObserver = Self.busynessObserver { busynessObserver.leaveBusy() } }
        let (_, response) = try await self.urlSession.data(for: urlRequest, delegate: nil)
        return try Self.handleResponse(response).status
    }

    func headers(urlRequest: URLRequest) async throws -> HTTP.Headers {
        
        var urlRequest = urlRequest
        urlRequest.httpMethod = HTTP.Method.HEAD.rawValue
        if let busynessObserver = Self.busynessObserver { busynessObserver.enterBusy() }
        defer { if let busynessObserver = Self.busynessObserver { busynessObserver.leaveBusy() } }
        let (_, response) = try await self.urlSession.data(for: urlRequest, delegate: nil)
        return try Self.handleResponse(response).headers
    }

    func upload<T: Encodable>(item: T, urlRequest: URLRequest, method: HTTP.Method = .POST) async throws -> HTTP.Status {

        var urlRequest = urlRequest
        urlRequest.httpMethod = method.rawValue
        let uploadData = try Self.prepareUpload(item: item, in: &urlRequest)
        if let busynessObserver = Self.busynessObserver { busynessObserver.enterBusy() }
        defer { if let busynessObserver = Self.busynessObserver { busynessObserver.leaveBusy() } }
        let (_, response) = try await self.urlSession.upload(for: urlRequest, from: uploadData, delegate: nil)
        return try Self.handleResponse(response).status
    }

    func binaryUpload(data: Data, urlRequest: URLRequest, method: HTTP.Method = .POST) async throws -> HTTP.Status {

        var urlRequest = urlRequest
        urlRequest.setValue(HTTP.MimeType.applicationOctetStream.rawValue, forHTTPHeaderField: HTTP.HeaderField.contentType.rawValue)
        urlRequest.httpMethod = method.rawValue
        if let busynessObserver = Self.busynessObserver { busynessObserver.enterBusy() }
        defer { if let busynessObserver = Self.busynessObserver { busynessObserver.leaveBusy() } }
        let (_, response) = try await self.urlSession.upload(for: urlRequest, from: data, delegate: nil)
        return try Self.handleResponse(response).status
    }

    func updownload<UP: Encodable, DOWN: Decodable>(item: UP, urlRequest: URLRequest, method: HTTP.Method = .POST) async throws -> DOWN {

        var urlRequest = urlRequest
        urlRequest.httpMethod = method.rawValue
        let uploadData = try Self.prepareUpload(item: item, in: &urlRequest)
        if let busynessObserver = Self.busynessObserver { busynessObserver.enterBusy() }
        defer { if let busynessObserver = Self.busynessObserver { busynessObserver.leaveBusy() } }
        let (data, response) = try await self.urlSession.upload(for: urlRequest, from: uploadData, delegate: nil)
        return try Self.handleIncoming(data: data, response: response)
    }

    func load(urlRequest: URLRequest, to destinationURL: URL) async throws -> HTTP.Headers {
        if let busynessObserver = Self.busynessObserver { busynessObserver.enterBusy() }
        defer { if let busynessObserver = Self.busynessObserver { busynessObserver.leaveBusy() } }
        let (url, response) = try await self.urlSession.download(for: urlRequest, delegate: nil)
        return try Self.handleFile(source: url, destination: destinationURL, response: response)
    }

}

internal extension Networking {

    static func prepareUpload<T: Encodable>(item: T, in urlRequest: inout URLRequest) throws -> Data {

        let uncompressed = try Cornucopia.Core.JSONEncoder().encode(item)
        urlRequest.setValue(HTTP.MimeType.applicationJSON.rawValue, forHTTPHeaderField: HTTP.HeaderField.contentType.rawValue)
        guard Self.shouldCompressUpload(urlRequest: urlRequest) else { return uncompressed }
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
    
    static func handleIncoming<T: Decodable>(data: Data, response: URLResponse) throws -> T {

        guard let httpResponse = response as? HTTPURLResponse else { throw Error.unexpectedResponse("\(type(of: response)) != HTTPURLResponse") }
        let status = HTTP.Status(rawValue: httpResponse.statusCode) ?? .Unknown
        let mimeType = HTTP.MimeType(rawValue: response.mimeType ?? "unknown/unknown") ?? .unknown
        guard status.responseType == .Success else {
            // We have an error, check whether it contains details or not.
            guard mimeType == .applicationJSON else {
                // No details or an unknown mime type.
                throw Error.unsuccessful(status)
            }
            guard let details = try? Cornucopia.Core.JSONDecoder().decode([String: AnyDecodable].self, from: data) else { throw Error.unsuccessful(status) }
            throw Error.unsuccessfulWithDetails(status, details: details)
        }
        switch mimeType {
            // This is the usual case. We try to decode into the requested type and return the resulting entity hierarchy.
            case .applicationJSON, .textJavascript:
                do {
                    let entity = try Cornucopia.Core.JSONDecoder().decode(T.self, from: data)
                    return entity
                } catch {
                    throw Error.decodingError(error)
                }

            // If we receive an octet stream and the requested type is a `Data`, we just pass it through.
            // (Although `Data` is indeed a valid `Decodable`, it is illegal as top-level JSON object.)
            case .applicationOctetStream where T.self == Data.self || T.self == Optional<Data>.self:
                return data as! T
            // Some servers return `application/x-dosexec` for `.bin` files, which we want as binary.
            case .applicationXDosexec where T.self == Data.self || T.self == Optional<Data>.self:
                return data as! T
            // Last, but not least, some return `application/binary`...
            case .applicationBinary where T.self == Data.self || T.self == Optional<Data>.self:
                return data as! T

            default:
                throw Error.unexpectedMimeType(response.mimeType ?? "unknown/unknown")
        }
    }
    
    static func handleResponse(_ response: URLResponse) throws -> HTTP.StatusAndHeaders {

        guard let httpResponse = response as? HTTPURLResponse else { throw Error.unexpectedResponse("\(type(of: response)) != HTTPURLResponse") }
        let status = HTTP.Status(rawValue: httpResponse.statusCode) ?? .Unknown
        guard status.responseType == .Success else { throw Error.unsuccessful(status) }
        let headers = httpResponse.allHeaderFields as? [String: String] ?? [:]
        return (status, headers)
    }
    
    static func handleFile(source: URL, destination: URL, response: URLResponse) throws -> HTTP.Headers {

        guard let httpResponse = response as? HTTPURLResponse else { throw Error.unexpectedResponse("\(type(of: response)) != HTTPURLResponse") }
        let status = HTTP.Status(rawValue: httpResponse.statusCode) ?? .Unknown
        guard status.responseType == .Success else { throw Error.unsuccessful(status) }

        try? FileManager.default.removeItem(at: destination) // might fail, if not existing, we don't care
        try FileManager.default.moveItem(at: source, to: destination)
        let headers = httpResponse.allHeaderFields as? [String: String] ?? [:]
        return headers
    }
}
