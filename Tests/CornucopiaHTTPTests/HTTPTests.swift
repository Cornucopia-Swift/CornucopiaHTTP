import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import CornucopiaHTTP

final class HTTPTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        await setupMocks()
    }

    override func tearDown() async throws {
        clearMocks()
        try await super.tearDown()
    }

    // MARK: - GET Tests

    func testStaticGET_Success() async throws {
        let url = URL(string: "https://api.example.com/users")!
        let mockData = """
        {"id": 1, "name": "John Doe"}
        """.data(using: .utf8)!
        
        Networking.registerMockData(mockData, httpStatus: .OK, contentType: .applicationJSON, for: url)
        
        let result: TestUser = try await HTTP.GET(from: URLRequest(url: url))
        XCTAssertEqual(result.id, 1)
        XCTAssertEqual(result.name, "John Doe")
    }

    func testStaticGET_Array() async throws {
        let url = URL(string: "https://api.example.com/users")!
        let mockData = """
        [{"id": 1, "name": "John"}, {"id": 2, "name": "Jane"}]
        """.data(using: .utf8)!
        
        Networking.registerMockData(mockData, httpStatus: .OK, contentType: .applicationJSON, for: url)
        
        let result: [TestUser] = try await HTTP.GET(from: URLRequest(url: url))
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].name, "John")
        XCTAssertEqual(result[1].name, "Jane")
    }

    func testStaticGET_BinaryData() async throws {
        let url = URL(string: "https://api.example.com/file")!
        let mockData = Data([0x00, 0x01, 0x02, 0x03])
        
        Networking.registerMockData(mockData, httpStatus: .OK, contentType: .applicationOctetStream, for: url)
        
        let result: Data = try await HTTP.GET(from: URLRequest(url: url))
        XCTAssertEqual(result, mockData)
    }

    func testStaticGET_ToFile() async throws {
        let url = URL(string: "https://api.example.com/download")!
        let mockData = "File content".data(using: .utf8)!
        let destination = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        
        Networking.registerMockData(mockData, httpStatus: .OK, contentType: HTTP.MimeType.textPlain, for: url)
        
        let headers = try await HTTP.GET(from: URLRequest(url: url), to: destination)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertEqual(headers[HTTP.HeaderField.contentType.rawValue], HTTP.MimeType.textPlain.rawValue)
        
        let savedData = try Data(contentsOf: destination)
        XCTAssertEqual(savedData, mockData)
        
        try? FileManager.default.removeItem(at: destination)
    }

    // MARK: - POST Tests

    func testStaticPOST_CreateAndReturn() async throws {
        let url = URL(string: "https://api.example.com/users")!
        let newUser = TestUser(id: nil, name: "New User")
        let responseData = """
        {"id": 123, "name": "New User"}
        """.data(using: .utf8)!
        
        Networking.registerMockData(responseData, httpStatus: .Created, contentType: .applicationJSON, for: url)
        
        let result: TestUser = try await HTTP.POST(item: newUser, to: URLRequest(url: url))
        XCTAssertEqual(result.id, 123)
        XCTAssertEqual(result.name, "New User")
    }

    func testStaticPOST_StatusOnly() async throws {
        let url = URL(string: "https://api.example.com/actions")!
        let action = TestAction(type: "test")
        
        Networking.registerMockData(Data(), httpStatus: .Accepted, contentType: .applicationJSON, for: url)
        
        let status = try await HTTP.POST(item: action, via: URLRequest(url: url))
        XCTAssertEqual(status, .Accepted)
    }

    func testStaticPOST_BinaryData() async throws {
        let url = URL(string: "https://api.example.com/upload")!
        let binaryData = Data([0x89, 0x50, 0x4E, 0x47])
        
        Networking.registerMockData(Data(), httpStatus: .Created, contentType: .applicationOctetStream, for: url)
        
        let status = try await HTTP.POST(data: binaryData, via: URLRequest(url: url))
        XCTAssertEqual(status, .Created)
    }

    // MARK: - PUT Tests

    func testStaticPUT() async throws {
        let url = URL(string: "https://api.example.com/users/1")!
        let user = TestUser(id: 1, name: "Updated User")
        let responseData = """
        {"id": 1, "name": "Updated User"}
        """.data(using: .utf8)!
        
        Networking.registerMockData(responseData, httpStatus: .OK, contentType: .applicationJSON, for: url)
        
        let result: TestUser = try await HTTP.PUT(item: user, to: URLRequest(url: url))
        XCTAssertEqual(result.id, 1)
        XCTAssertEqual(result.name, "Updated User")
    }

    // MARK: - PATCH Tests

    func testStaticPATCH() async throws {
        let url = URL(string: "https://api.example.com/users/1")!
        let patch = TestUserPatch(name: "Patched Name")
        let responseData = """
        {"id": 1, "name": "Patched Name"}
        """.data(using: .utf8)!
        
        Networking.registerMockData(responseData, httpStatus: .OK, contentType: .applicationJSON, for: url)
        
        let result: TestUser = try await HTTP.PATCH(item: patch, to: URLRequest(url: url))
        XCTAssertEqual(result.id, 1)
        XCTAssertEqual(result.name, "Patched Name")
    }

    func testStaticPATCH_SameType() async throws {
        let url = URL(string: "https://api.example.com/users/1")!
        var user = TestUser(id: 1, name: "Original")
        user.name = "Patched"
        let responseData = """
        {"id": 1, "name": "Patched"}
        """.data(using: .utf8)!
        
        Networking.registerMockData(responseData, httpStatus: .OK, contentType: .applicationJSON, for: url)
        
        let result: TestUser = try await HTTP.PATCH(item: user, to: URLRequest(url: url))
        XCTAssertEqual(result.id, 1)
        XCTAssertEqual(result.name, "Patched")
    }

    // MARK: - DELETE Tests

    func testStaticDELETE() async throws {
        let url = URL(string: "https://api.example.com/users/1")!
        
        Networking.registerMockData(Data(), httpStatus: .NoContent, contentType: .applicationJSON, for: url)
        
        let status = try await HTTP.DELETE(via: URLRequest(url: url))
        XCTAssertEqual(status, .NoContent)
    }

    // MARK: - HEAD Tests

    func testStaticHEAD() async throws {
        let url = URL(string: "https://api.example.com/users/1")!
        
        Networking.registerMockData(Data(), httpStatus: .OK, contentType: .applicationJSON, for: url)
        
        let headers = try await HTTP.HEAD(at: URLRequest(url: url))
        XCTAssertEqual(headers[HTTP.HeaderField.contentType.rawValue], HTTP.MimeType.applicationJSON.rawValue)
    }

    // MARK: - Helper Methods

    private func setupMocks() async {
        // Common setup for mocks can go here if needed
    }

    private func clearMocks() {
        // Clear any registered mocks between tests
        // Note: This would require a public clearMocks method on Networking
    }
}

// MARK: - Test Models

private struct TestUser: Codable {
    let id: Int?
    var name: String
}

private struct TestUserPatch: Codable {
    let name: String
}

private struct TestAction: Codable {
    let type: String
}

