import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import CornucopiaHTTP

final class NetworkingTests: XCTestCase {

    var networking: Networking!

    override func setUp() async throws {
        try await super.setUp()
        networking = Networking()
    }

    override func tearDown() async throws {
        networking = nil
        try await super.tearDown()
    }

    // MARK: - Instance Method Tests

    func testInstanceGET_Success() async throws {
        let url = URL(string: "https://api.example.com/users/1")!
        let mockData = """
        {"id": 1, "name": "Test User", "email": "test@example.com"}
        """.data(using: .utf8)!
        
        Networking.registerMockData(mockData, httpStatus: .OK, contentType: .applicationJSON, for: url)
        
        let result: TestUser = try await networking.GET(from: URLRequest(url: url))
        XCTAssertEqual(result.id, 1)
        XCTAssertEqual(result.name, "Test User")
        XCTAssertEqual(result.email, "test@example.com")
    }

    func testInstancePOST_Success() async throws {
        let url = URL(string: "https://api.example.com/users")!
        let newUser = TestUser(id: nil, name: "New User", email: "new@example.com")
        let responseData = """
        {"id": 42, "name": "New User", "email": "new@example.com"}
        """.data(using: .utf8)!
        
        Networking.registerMockData(responseData, httpStatus: .Created, contentType: .applicationJSON, for: url)
        
        let result: TestUser = try await networking.POST(item: newUser, to: URLRequest(url: url))
        XCTAssertEqual(result.id, 42)
        XCTAssertEqual(result.name, "New User")
        XCTAssertEqual(result.email, "new@example.com")
    }

    func testInstancePOST_DifferentTypes() async throws {
        let url = URL(string: "https://api.example.com/users")!
        let createRequest = CreateUserRequest(name: "John", email: "john@example.com")
        let responseData = """
        {"id": 123, "name": "John", "email": "john@example.com"}
        """.data(using: .utf8)!
        
        Networking.registerMockData(responseData, httpStatus: .Created, contentType: .applicationJSON, for: url)
        
        let result: TestUser = try await networking.POST(item: createRequest, to: URLRequest(url: url))
        XCTAssertEqual(result.id, 123)
        XCTAssertEqual(result.name, "John")
        XCTAssertEqual(result.email, "john@example.com")
    }

    func testInstancePOST_StatusOnly() async throws {
        let url = URL(string: "https://api.example.com/notifications")!
        let notification = NotificationPayload(message: "Hello", recipient: "user@example.com")
        
        Networking.registerMockData(Data(), httpStatus: .Accepted, contentType: .applicationJSON, for: url)
        
        let status = try await networking.POST(item: notification, via: URLRequest(url: url))
        XCTAssertEqual(status, .Accepted)
    }

    func testInstancePOST_BinaryData() async throws {
        let url = URL(string: "https://api.example.com/files")!
        let imageData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) // PNG header
        
        Networking.registerMockData(Data(), httpStatus: .Created, contentType: .applicationOctetStream, for: url)
        
        let status = try await networking.POST(data: imageData, via: URLRequest(url: url))
        XCTAssertEqual(status, .Created)
    }

    func testInstanceDELETE_Success() async throws {
        let url = URL(string: "https://api.example.com/users/123")!
        
        Networking.registerMockData(Data(), httpStatus: .NoContent, contentType: .applicationJSON, for: url)
        
        let status = try await networking.DELETE(via: URLRequest(url: url))
        XCTAssertEqual(status, .NoContent)
    }

    func testInstanceHEAD_Success() async throws {
        let url = URL(string: "https://api.example.com/users/123")!
        
        Networking.registerMockData(Data(), httpStatus: .OK, contentType: .applicationJSON, for: url)
        
        let headers = try await networking.HEAD(at: URLRequest(url: url))
        XCTAssertEqual(headers[HTTP.HeaderField.contentType.rawValue], HTTP.MimeType.applicationJSON.rawValue)
        XCTAssertEqual(headers[HTTP.HeaderField.contentLength.rawValue], "0")
    }

    func testInstanceGET_ToFile() async throws {
        let url = URL(string: "https://api.example.com/download/file.txt")!
        let mockData = "This is test file content\nWith multiple lines\nAnd some data.".data(using: .utf8)!
        let destination = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test-\(UUID().uuidString).txt")
        
        Networking.registerMockData(mockData, httpStatus: .OK, contentType: HTTP.MimeType.textPlain, for: url)
        
        let headers = try await networking.GET(from: URLRequest(url: url), to: destination)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertEqual(headers[HTTP.HeaderField.contentType.rawValue], "text/plain")
        
        let savedData = try Data(contentsOf: destination)
        XCTAssertEqual(savedData, mockData)
        
        try? FileManager.default.removeItem(at: destination)
    }

    func testInstanceGET_ToFileWithProgress() async throws {
        let url = URL(string: "https://api.example.com/download/largefile.bin")!
        let mockData = Data(repeating: 0xFF, count: 1024) // 1KB of data
        let destination = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("progress-test-\(UUID().uuidString).bin")
        
        Networking.registerMockData(mockData, httpStatus: .OK, contentType: .applicationOctetStream, for: url)
        
        var progressCallbackCount = 0
        let progressObserver: Networking.ProgressObserver = { progress in
            progressCallbackCount += 1
            XCTAssertGreaterThanOrEqual(progress.fractionCompleted, 0.0)
            XCTAssertLessThanOrEqual(progress.fractionCompleted, 1.0)
        }
        
        let headers = try await networking.GET(from: URLRequest(url: url), to: destination, progressObserver: progressObserver)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertEqual(headers[HTTP.HeaderField.contentType.rawValue], HTTP.MimeType.applicationOctetStream.rawValue)
        
        let savedData = try Data(contentsOf: destination)
        XCTAssertEqual(savedData, mockData)
        
        // Note: Progress callbacks might not be called for mocked requests
        // This test primarily ensures the API works correctly
        
        try? FileManager.default.removeItem(at: destination)
    }

    // MARK: - Custom URLSession Tests

    func testCustomURLSession() {
        let customConfig = URLSessionConfiguration.default
        customConfig.timeoutIntervalForRequest = 30
        let customSession = URLSession(configuration: customConfig)
        
        Networking.customURLSession = customSession
        let networking = Networking()
        
        XCTAssertEqual(networking.urlSession, customSession)
        
        // Reset to default
        Networking.customURLSession = nil
    }

    // MARK: - Internal Method Tests (via HTTP static methods)

    func testHandleIncomingJSONDecoding() async throws {
        let url = URL(string: "https://api.example.com/complex")!
        let complexData = """
        {
            "users": [
                {"id": 1, "name": "Alice", "email": "alice@example.com"},
                {"id": 2, "name": "Bob", "email": "bob@example.com"}
            ],
            "metadata": {
                "total": 2,
                "page": 1
            }
        }
        """.data(using: .utf8)!
        
        Networking.registerMockData(complexData, httpStatus: .OK, contentType: .applicationJSON, for: url)
        
        let result: ComplexResponse = try await HTTP.GET(from: URLRequest(url: url))
        XCTAssertEqual(result.users.count, 2)
        XCTAssertEqual(result.users[0].name, "Alice")
        XCTAssertEqual(result.metadata.total, 2)
    }

    func testHandleIncomingTextJavascript() async throws {
        let url = URL(string: "https://api.example.com/jsonp")!
        let mockData = """
        {"message": "Hello from JSONP"}
        """.data(using: .utf8)!
        
        // Using text/javascript content type (should be treated as JSON)
        Networking.registerMockData(mockData, httpStatus: .OK, contentType: .textJavascript, for: url)
        
        let result: SimpleMessage = try await HTTP.GET(from: URLRequest(url: url))
        XCTAssertEqual(result.message, "Hello from JSONP")
    }
}

// MARK: - Test Models

private struct TestUser: Codable {
    let id: Int?
    let name: String
    let email: String
}

private struct CreateUserRequest: Codable {
    let name: String
    let email: String
}

private struct NotificationPayload: Codable {
    let message: String
    let recipient: String
}

private struct ComplexResponse: Codable {
    let users: [TestUser]
    let metadata: Metadata
    
    struct Metadata: Codable {
        let total: Int
        let page: Int
    }
}

private struct SimpleMessage: Codable {
    let message: String
}

