import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import CornucopiaHTTP

final class MockingTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        clearAllMocks()
    }

    override func tearDown() async throws {
        clearAllMocks()
        try await super.tearDown()
    }

    // MARK: - Basic Mocking Tests

    func testRegisterMockData() {
        let url = URL(string: "https://api.example.com/test")!
        let mockData = "test data".data(using: .utf8)!
        
        Networking.registerMockData(mockData, httpStatus: .OK, contentType: .applicationJSON, for: url)
        
        let mock = Networking.mock(for: URLRequest(url: url))
        XCTAssertNotNil(mock)
        XCTAssertEqual(mock?.data, mockData)
        XCTAssertEqual(mock?.response.statusCode, 200)
        XCTAssertEqual(mock?.response.allHeaderFields[HTTP.HeaderField.contentType.rawValue] as? String, HTTP.MimeType.applicationJSON.rawValue)
        XCTAssertEqual(mock?.response.allHeaderFields[HTTP.HeaderField.contentLength.rawValue] as? String, "\(mockData.count)")
    }

    func testMockNotFound() {
        let url = URL(string: "https://api.example.com/nonexistent")!
        let mock = Networking.mock(for: URLRequest(url: url))
        XCTAssertNil(mock)
    }

    func testMockWithMissingURL() {
        var urlRequest = URLRequest(url: URL(string: "https://example.com")!)
        urlRequest.url = nil
        
        let mock = Networking.mock(for: urlRequest)
        XCTAssertNil(mock)
    }

    // MARK: - Different Content Types

    func testMockJSON() {
        let url = URL(string: "https://api.example.com/json")!
        let jsonData = """
        {"name": "test", "value": 42}
        """.data(using: .utf8)!
        
        Networking.registerMockData(jsonData, httpStatus: .OK, contentType: .applicationJSON, for: url)
        
        let mock = Networking.mock(for: URLRequest(url: url))
        XCTAssertEqual(mock?.response.allHeaderFields[HTTP.HeaderField.contentType.rawValue] as? String, "application/json")
    }

    func testMockBinary() {
        let url = URL(string: "https://api.example.com/binary")!
        let binaryData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        
        Networking.registerMockData(binaryData, httpStatus: .OK, contentType: .applicationOctetStream, for: url)
        
        let mock = Networking.mock(for: URLRequest(url: url))
        XCTAssertEqual(mock?.data, binaryData)
        XCTAssertEqual(mock?.response.allHeaderFields[HTTP.HeaderField.contentType.rawValue] as? String, "application/octet-stream")
    }

    func testMockText() {
        let url = URL(string: "https://api.example.com/text")!
        let textData = "Plain text content".data(using: .utf8)!
        
        Networking.registerMockData(textData, httpStatus: .OK, contentType: HTTP.MimeType.textPlain, for: url)
        
        let mock = Networking.mock(for: URLRequest(url: url))
        XCTAssertEqual(mock?.response.allHeaderFields[HTTP.HeaderField.contentType.rawValue] as? String, "text/plain")
    }

    // MARK: - Different HTTP Status Codes

    func testMockSuccess() {
        let url = URL(string: "https://api.example.com/success")!
        let data = Data()
        
        Networking.registerMockData(data, httpStatus: .OK, contentType: .applicationJSON, for: url)
        
        let mock = Networking.mock(for: URLRequest(url: url))
        XCTAssertEqual(mock?.response.statusCode, 200)
    }

    func testMockCreated() {
        let url = URL(string: "https://api.example.com/created")!
        let data = Data()
        
        Networking.registerMockData(data, httpStatus: .Created, contentType: .applicationJSON, for: url)
        
        let mock = Networking.mock(for: URLRequest(url: url))
        XCTAssertEqual(mock?.response.statusCode, 201)
    }

    func testMockNotFoundWithData() {
        let url = URL(string: "https://api.example.com/notfound")!
        let data = Data()
        
        Networking.registerMockData(data, httpStatus: .NotFound, contentType: .applicationJSON, for: url)
        
        let mock = Networking.mock(for: URLRequest(url: url))
        XCTAssertEqual(mock?.response.statusCode, 404)
    }

    func testMockServerError() {
        let url = URL(string: "https://api.example.com/error")!
        let data = Data()
        
        Networking.registerMockData(data, httpStatus: .InternalServerError, contentType: .applicationJSON, for: url)
        
        let mock = Networking.mock(for: URLRequest(url: url))
        XCTAssertEqual(mock?.response.statusCode, 500)
    }

    // MARK: - Integration with HTTP Methods

    func testMockGET() async throws {
        let url = URL(string: "https://api.example.com/users/1")!
        let userData = """
        {"id": 1, "name": "Mock User", "email": "mock@example.com"}
        """.data(using: .utf8)!
        
        Networking.registerMockData(userData, httpStatus: .OK, contentType: .applicationJSON, for: url)
        
        let result: MockUser = try await HTTP.GET(from: URLRequest(url: url))
        XCTAssertEqual(result.id, 1)
        XCTAssertEqual(result.name, "Mock User")
        XCTAssertEqual(result.email, "mock@example.com")
    }

    func testMockPOST() async throws {
        let url = URL(string: "https://api.example.com/users")!
        let newUser = MockUser(id: nil, name: "New User", email: "new@example.com")
        let responseData = """
        {"id": 123, "name": "New User", "email": "new@example.com"}
        """.data(using: .utf8)!
        
        Networking.registerMockData(responseData, httpStatus: .Created, contentType: .applicationJSON, for: url)
        
        let result: MockUser = try await HTTP.POST(item: newUser, to: URLRequest(url: url))
        XCTAssertEqual(result.id, 123)
        XCTAssertEqual(result.name, "New User")
    }

    func testMockPUT() async throws {
        let url = URL(string: "https://api.example.com/users/1")!
        let updatedUser = MockUser(id: 1, name: "Updated User", email: "updated@example.com")
        let responseData = """
        {"id": 1, "name": "Updated User", "email": "updated@example.com"}
        """.data(using: .utf8)!
        
        Networking.registerMockData(responseData, httpStatus: .OK, contentType: .applicationJSON, for: url)
        
        let result: MockUser = try await HTTP.PUT(item: updatedUser, to: URLRequest(url: url))
        XCTAssertEqual(result.id, 1)
        XCTAssertEqual(result.name, "Updated User")
    }

    func testMockDELETE() async throws {
        let url = URL(string: "https://api.example.com/users/1")!
        
        Networking.registerMockData(Data(), httpStatus: .NoContent, contentType: .applicationJSON, for: url)
        
        let status = try await HTTP.DELETE(via: URLRequest(url: url))
        XCTAssertEqual(status, .NoContent)
    }

    func testMockHEAD() async throws {
        let url = URL(string: "https://api.example.com/users/1")!
        
        Networking.registerMockData(Data(), httpStatus: .OK, contentType: .applicationJSON, for: url)
        
        let headers = try await HTTP.HEAD(at: URLRequest(url: url))
        XCTAssertEqual(headers[HTTP.HeaderField.contentType.rawValue], HTTP.MimeType.applicationJSON.rawValue)
    }

    // MARK: - Multiple Mocks

    func testMultipleMocks() {
        let url1 = URL(string: "https://api.example.com/endpoint1")!
        let url2 = URL(string: "https://api.example.com/endpoint2")!
        
        let data1 = "data1".data(using: .utf8)!
        let data2 = "data2".data(using: .utf8)!
        
        Networking.registerMockData(data1, httpStatus: .OK, contentType: .applicationJSON, for: url1)
        Networking.registerMockData(data2, httpStatus: .Created, contentType: HTTP.MimeType.textPlain, for: url2)
        
        let mock1 = Networking.mock(for: URLRequest(url: url1))
        let mock2 = Networking.mock(for: URLRequest(url: url2))
        
        XCTAssertEqual(mock1?.data, data1)
        XCTAssertEqual(mock1?.response.statusCode, 200)
        
        XCTAssertEqual(mock2?.data, data2)
        XCTAssertEqual(mock2?.response.statusCode, 201)
    }

    func testMockOverwrite() {
        let url = URL(string: "https://api.example.com/overwrite")!
        
        let originalData = "original".data(using: .utf8)!
        let newData = "new".data(using: .utf8)!
        
        // Register first mock
        Networking.registerMockData(originalData, httpStatus: .OK, contentType: .applicationJSON, for: url)
        
        let firstMock = Networking.mock(for: URLRequest(url: url))
        XCTAssertEqual(firstMock?.data, originalData)
        
        // Overwrite with new mock
        Networking.registerMockData(newData, httpStatus: .Created, contentType: HTTP.MimeType.textPlain, for: url)
        
        let secondMock = Networking.mock(for: URLRequest(url: url))
        XCTAssertEqual(secondMock?.data, newData)
        XCTAssertEqual(secondMock?.response.statusCode, 201)
    }

    // MARK: - Error Scenarios with Mocks

    func testMockError() async throws {
        let url = URL(string: "https://api.example.com/error")!
        let errorData = """
        {"error": "Not found", "code": 404}
        """.data(using: .utf8)!
        
        Networking.registerMockData(errorData, httpStatus: .NotFound, contentType: .applicationJSON, for: url)
        
        do {
            let _: MockUser = try await HTTP.GET(from: URLRequest(url: url))
            XCTFail("Expected error to be thrown")
        } catch let error as Networking.Error {
            if case .unsuccessfulWithDetails(let status, let details) = error {
                XCTAssertEqual(status, .NotFound)
                XCTAssertEqual(details["error"]?.value as? String, "Not found")
            } else {
                XCTFail("Expected unsuccessfulWithDetails error")
            }
        }
    }

    func testMockInvalidJSON() async throws {
        let url = URL(string: "https://api.example.com/invalid")!
        let invalidJSON = "{ invalid json".data(using: .utf8)!
        
        Networking.registerMockData(invalidJSON, httpStatus: .OK, contentType: .applicationJSON, for: url)
        
        do {
            let _: MockUser = try await HTTP.GET(from: URLRequest(url: url))
            XCTFail("Expected error to be thrown")
        } catch let error as Networking.Error {
            if case .decodingError(_) = error {
                // Expected
            } else {
                XCTFail("Expected decodingError")
            }
        }
    }

    // MARK: - Content Length Verification

    func testMockContentLength() {
        let url = URL(string: "https://api.example.com/length")!
        let testData = "This is test data with specific length".data(using: .utf8)!
        
        Networking.registerMockData(testData, httpStatus: .OK, contentType: HTTP.MimeType.textPlain, for: url)
        
        let mock = Networking.mock(for: URLRequest(url: url))
        let contentLengthHeader = mock?.response.allHeaderFields[HTTP.HeaderField.contentLength.rawValue] as? String
        
        XCTAssertEqual(contentLengthHeader, "\(testData.count)")
        XCTAssertEqual(Int(contentLengthHeader ?? "0"), testData.count)
    }

    func testMockEmptyData() {
        let url = URL(string: "https://api.example.com/empty")!
        let emptyData = Data()
        
        Networking.registerMockData(emptyData, httpStatus: .NoContent, contentType: .applicationJSON, for: url)
        
        let mock = Networking.mock(for: URLRequest(url: url))
        XCTAssertEqual(mock?.data.count, 0)
        XCTAssertEqual(mock?.response.allHeaderFields[HTTP.HeaderField.contentLength.rawValue] as? String, "0")
    }

    // MARK: - Helper Methods

    private func clearAllMocks() {
        // This would require a public method on Networking to clear all mocks
        // For now, we rely on test isolation through different URLs
    }
}

// MARK: - Test Models

private struct MockUser: Codable {
    let id: Int?
    let name: String
    let email: String
}

// MARK: - Custom MIME Types

