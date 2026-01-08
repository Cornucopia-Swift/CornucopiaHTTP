import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import CornucopiaCore
@testable import CornucopiaHTTP

final class MultipartFormDataTests: XCTestCase {

    func testPrepareMultipartUploadBuildsExpectedBody() throws {
        let boundary = "Boundary-Test"
        var request = URLRequest(url: URL(string: "https://api.example.com/upload")!)
        let payload = TestHelpers.TestUser(id: 1, name: "Alice", email: "alice@example.com")
        let jsonPart = try Networking.MultipartPart.json(payload, name: "payload")
        let binaryPart = Networking.MultipartPart(
            name: "file",
            data: Data("abc".utf8),
            filename: "file.bin",
            mimeType: .applicationOctetStream
        )

        let body = try Networking.prepareMultipartUpload(parts: [jsonPart, binaryPart], in: &request, boundary: boundary)

        XCTAssertEqual(
            request.value(forHTTPHeaderField: HTTP.HeaderField.contentType.rawValue),
            "\(HTTP.MimeType.multipartFormData.rawValue); boundary=\(boundary)"
        )

        let jsonString = String(data: try Cornucopia.Core.JSONEncoder().encode(payload), encoding: .utf8)!
        let lineBreak = "\r\n"
        let expectedBody = [
            "--\(boundary)",
            "Content-Disposition: form-data; name=\"payload\"",
            "Content-Type: application/json",
            "",
            jsonString,
            "--\(boundary)",
            "Content-Disposition: form-data; name=\"file\"; filename=\"file.bin\"",
            "Content-Type: application/octet-stream",
            "",
            "abc",
            "--\(boundary)--",
            ""
        ].joined(separator: lineBreak)

        let bodyString = String(data: body, encoding: .utf8)
        XCTAssertEqual(bodyString, expectedBody)
    }

    func testQuickMultipartJSONBinaryPOST_StatusOnly() async throws {
        let url = URL(string: "https://api.example.com/upload")!
        let payload = TestHelpers.TestUser(id: 7, name: "Upload", email: "upload@example.com")
        let binary = Data([0x01, 0x02, 0x03])

        Networking.registerMockData(Data(), httpStatus: .Created, contentType: .applicationJSON, for: url)

        let status = try await Networking().POST(json: payload, binary: binary, via: URLRequest(url: url))
        XCTAssertEqual(status, .Created)
    }
}
