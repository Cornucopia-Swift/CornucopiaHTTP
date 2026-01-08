//
//  Cornucopia – (C) Dr. Lauer Information Technology
//
import CornucopiaCore
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension Networking {

    /// A single part of a `multipart/form-data` request body.
    struct MultipartPart {
        public let name: String
        public let data: Data
        public let filename: String?
        public let mimeType: String?

        public init(name: String, data: Data, filename: String? = nil, mimeType: String? = nil) {
            self.name = name
            self.data = data
            self.filename = filename
            self.mimeType = mimeType
        }

        public init(name: String, data: Data, filename: String? = nil, mimeType: HTTP.MimeType) {
            self.init(name: name, data: data, filename: filename, mimeType: mimeType.rawValue)
        }

        public static func json<T: Encodable>(_ value: T, name: String = "json", filename: String? = nil) throws -> MultipartPart {
            let data = try Cornucopia.Core.JSONEncoder().encode(value)
            return MultipartPart(name: name, data: data, filename: filename, mimeType: HTTP.MimeType.applicationJSON)
        }
    }

    /// Issues a HTTP POST request with multipart data and returns the status code.
    @discardableResult
    func POST(multipart parts: [MultipartPart], via urlRequest: URLRequest) async throws -> HTTP.Status {
        try await self.multipartUpload(parts: parts, urlRequest: urlRequest)
    }

    /// Issues a HTTP POST request with multipart data and returns a `Decodable` response.
    func POST<DOWN: Decodable>(multipart parts: [MultipartPart], to urlRequest: URLRequest) async throws -> DOWN {
        try await self.multipartUpdownload(parts: parts, urlRequest: urlRequest)
    }

    /// Issues a HTTP POST request with a JSON payload and a binary attachment.
    @discardableResult
    func POST<UP: Encodable>(
        json: UP,
        binary: Data,
        via urlRequest: URLRequest,
        jsonFieldName: String = "json",
        binaryFieldName: String = "file",
        binaryFilename: String = "file.bin",
        binaryMimeType: HTTP.MimeType = .applicationOctetStream
    ) async throws -> HTTP.Status {
        let jsonPart = try MultipartPart.json(json, name: jsonFieldName)
        let binaryPart = MultipartPart(name: binaryFieldName, data: binary, filename: binaryFilename, mimeType: binaryMimeType)
        return try await self.POST(multipart: [jsonPart, binaryPart], via: urlRequest)
    }
}

internal extension Networking {

    func multipartUpload(parts: [MultipartPart], urlRequest: URLRequest, method: HTTP.Method = .POST) async throws -> HTTP.Status {
        var urlRequest = urlRequest
        urlRequest.httpMethod = method.rawValue
        let uploadData = try Self.prepareMultipartUpload(parts: parts, in: &urlRequest)
        if let mock = Self.mock(for: urlRequest) { return try Self.handleResponse(mock.response).status }
        if let busynessObserver = Self.busynessObserver { busynessObserver.enterBusy() }
        defer { if let busynessObserver = Self.busynessObserver { busynessObserver.leaveBusy() } }
        let (_, response) = try await self.urlSession.upload(for: urlRequest, from: uploadData, delegate: nil)
        return try Self.handleResponse(response).status
    }

    func multipartUpdownload<DOWN: Decodable>(parts: [MultipartPart], urlRequest: URLRequest, method: HTTP.Method = .POST) async throws -> DOWN {
        var urlRequest = urlRequest
        urlRequest.httpMethod = method.rawValue
        let uploadData = try Self.prepareMultipartUpload(parts: parts, in: &urlRequest)
        if let mock = Self.mock(for: urlRequest) { return try Self.handleIncoming(data: mock.data, response: mock.response) }
        if let busynessObserver = Self.busynessObserver { busynessObserver.enterBusy() }
        defer { if let busynessObserver = Self.busynessObserver { busynessObserver.leaveBusy() } }
        let (data, response) = try await self.urlSession.upload(for: urlRequest, from: uploadData, delegate: nil)
        return try Self.handleIncoming(data: data, response: response)
    }

    static func prepareMultipartUpload(parts: [MultipartPart], in urlRequest: inout URLRequest, boundary: String? = nil) throws -> Data {
        guard !parts.isEmpty else { throw Error.unsuitableRequest("Multipart upload requires at least one part") }
        let existingBoundary = Self.multipartBoundary(from: urlRequest)
        let usedBoundary = boundary ?? existingBoundary ?? Self.makeMultipartBoundary()
        urlRequest.setValue("\(HTTP.MimeType.multipartFormData.rawValue); boundary=\(usedBoundary)", forHTTPHeaderField: HTTP.HeaderField.contentType.rawValue)
        return Self.buildMultipartBody(parts: parts, boundary: usedBoundary)
    }

    static func buildMultipartBody(parts: [MultipartPart], boundary: String) -> Data {
        let lineBreak = "\r\n"
        var body = Data()

        func append(_ string: String) {
            body.append(contentsOf: string.utf8)
        }

        for part in parts {
            append("--\(boundary)\(lineBreak)")
            var disposition = "Content-Disposition: form-data; name=\"\(part.name)\""
            if let filename = part.filename {
                disposition += "; filename=\"\(filename)\""
            }
            append("\(disposition)\(lineBreak)")
            if let mimeType = part.mimeType {
                append("Content-Type: \(mimeType)\(lineBreak)")
            }
            append(lineBreak)
            body.append(part.data)
            append(lineBreak)
        }

        append("--\(boundary)--\(lineBreak)")
        return body
    }

    static func makeMultipartBoundary() -> String {
        "Boundary-\(UUID().uuidString)"
    }

    static func multipartBoundary(from urlRequest: URLRequest) -> String? {
        guard let contentType = urlRequest.value(forHTTPHeaderField: HTTP.HeaderField.contentType.rawValue) else { return nil }
        return Self.multipartBoundary(from: contentType)
    }

    static func multipartBoundary(from contentType: String) -> String? {
        for chunk in contentType.split(separator: ";") {
            let trimmed = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.lowercased().hasPrefix("boundary=") else { continue }
            let value = trimmed.dropFirst("boundary=".count)
            return value.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }
        return nil
    }
}
