//
//  Cornucopia – (C) Dr. Lauer Information Technology
//
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

extension Networking {

    /// A networking mock is a tuple composed out of a ``Data`` and a ``HTTPURLResponse`` object.
    public typealias Mock = (data: Data, response: HTTPURLResponse)
    
    private static var mocks: [URL: Mock] = [:]

    /// Register a networking mock.
    public static func registerMockData(_ data: Data, httpStatus: HTTP.Status, contentType: HTTP.MimeType, for url: URL) {
        let headers: [String: String] = [
            HTTP.HeaderField.contentType.rawValue: contentType.rawValue,
            HTTP.HeaderField.contentLength.rawValue: "\(data.count)",
        ]
        guard let response = HTTPURLResponse(url: url, statusCode: httpStatus.rawValue, httpVersion: "HTTP/1.1", headerFields: headers) else { return }
        self.mocks[url] = (data, response)
    }

    /// Return the networking mock, if existing.
    public static func mock(for urlRequest: URLRequest) -> Mock? {
        guard let url = urlRequest.url else { return nil }
        return Self.mocks[url]
    }
}
