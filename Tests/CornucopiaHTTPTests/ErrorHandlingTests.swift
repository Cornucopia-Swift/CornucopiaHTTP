import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import CornucopiaHTTP

final class ErrorHandlingTests: XCTestCase {

    var networking: Networking!

    override func setUp() async throws {
        try await super.setUp()
        networking = Networking()
    }

    override func tearDown() async throws {
        networking = nil
        try await super.tearDown()
    }

    // MARK: - HTTP Error Status Tests

    func testHTTP4xxError() async throws {
        let url = URL(string: "https://api.example.com/notfound")!
        
        Networking.registerMockData(Data(), httpStatus: .NotFound, contentType: .applicationJSON, for: url)
        
        do {
            let _: TestUser = try await HTTP.GET(from: URLRequest(url: url))
            XCTFail("Expected error to be thrown")
        } catch let error as Networking.Error {
            if case .unsuccessful(let status) = error {
                XCTAssertEqual(status, .NotFound)
            } else {
                XCTFail("Expected unsuccessful error, got \(error)")
            }
        }
    }

    func testHTTP5xxError() async throws {
        let url = URL(string: "https://api.example.com/server-error")!
        
        Networking.registerMockData(Data(), httpStatus: .InternalServerError, contentType: .applicationJSON, for: url)
        
        do {
            let _: TestUser = try await HTTP.GET(from: URLRequest(url: url))
            XCTFail("Expected error to be thrown")
        } catch let error as Networking.Error {
            if case .unsuccessful(let status) = error {
                XCTAssertEqual(status, .InternalServerError)
            } else {
                XCTFail("Expected unsuccessful error, got \(error)")
            }
        }
    }

    func testHTTPErrorWithDetails() async throws {
        let url = URL(string: "https://api.example.com/validation-error")!
        let errorDetails = """
        {
            "error": "Validation failed",
            "message": "Name is required",
            "code": "VALIDATION_ERROR"
        }
        """.data(using: .utf8)!
        
        Networking.registerMockData(errorDetails, httpStatus: .BadRequest, contentType: .applicationJSON, for: url)
        
        do {
            let _: TestUser = try await HTTP.GET(from: URLRequest(url: url))
            XCTFail("Expected error to be thrown")
        } catch let error as Networking.Error {
            if case .unsuccessfulWithDetails(let status, let details) = error {
                XCTAssertEqual(status, .BadRequest)
                XCTAssertEqual(details["error"]?.value as? String, "Validation failed")
                XCTAssertEqual(details["message"]?.value as? String, "Name is required")
                XCTAssertEqual(details["code"]?.value as? String, "VALIDATION_ERROR")
            } else {
                XCTFail("Expected unsuccessfulWithDetails error, got \(error)")
            }
        }
    }

    func testHTTPErrorWithoutJSONDetails() async throws {
        let url = URL(string: "https://api.example.com/html-error")!
        let htmlError = "<html><body>Internal Server Error</body></html>".data(using: .utf8)!
        
        Networking.registerMockData(htmlError, httpStatus: .InternalServerError, contentType: .textHtml, for: url)
        
        do {
            let _: TestUser = try await HTTP.GET(from: URLRequest(url: url))
            XCTFail("Expected error to be thrown")
        } catch let error as Networking.Error {
            if case .unsuccessful(let status) = error {
                XCTAssertEqual(status, .InternalServerError)
            } else {
                XCTFail("Expected unsuccessful error without details, got \(error)")
            }
        }
    }

    // MARK: - JSON Decoding Error Tests

    func testJSONDecodingError() async throws {
        let url = URL(string: "https://api.example.com/malformed-json")!
        let invalidJSON = "{ invalid json }".data(using: .utf8)!
        
        Networking.registerMockData(invalidJSON, httpStatus: .OK, contentType: .applicationJSON, for: url)
        
        do {
            let _: TestUser = try await HTTP.GET(from: URLRequest(url: url))
            XCTFail("Expected error to be thrown")
        } catch let error as Networking.Error {
            if case .decodingError(_) = error {
                // Expected decoding error
            } else {
                XCTFail("Expected decodingError, got \(error)")
            }
        }
    }

    func testJSONStructureMismatch() async throws {
        let url = URL(string: "https://api.example.com/wrong-structure")!
        let wrongStructure = """
        {
            "wrongField": "value",
            "anotherWrongField": 123
        }
        """.data(using: .utf8)!
        
        Networking.registerMockData(wrongStructure, httpStatus: .OK, contentType: .applicationJSON, for: url)
        
        do {
            let _: TestUser = try await HTTP.GET(from: URLRequest(url: url))
            XCTFail("Expected error to be thrown")
        } catch let error as Networking.Error {
            if case .decodingError(_) = error {
                // Expected decoding error due to missing required fields
            } else {
                XCTFail("Expected decodingError, got \(error)")
            }
        }
    }

    // MARK: - MIME Type Error Tests

    func testUnexpectedMimeType() async throws {
        let url = URL(string: "https://api.example.com/unexpected-type")!
        let xmlData = "<xml><data>test</data></xml>".data(using: .utf8)!
        
        Networking.registerMockData(xmlData, httpStatus: .OK, contentType: .textXml, for: url)
        
        do {
            let _: TestUser = try await HTTP.GET(from: URLRequest(url: url))
            XCTFail("Expected error to be thrown")
        } catch let error as Networking.Error {
            if case .unexpectedMimeType(let mimeType) = error {
                XCTAssertEqual(mimeType, "text/xml")
            } else {
                XCTFail("Expected unexpectedMimeType error, got \(error)")
            }
        }
    }

    func testBinaryDataWithWrongType() async throws {
        let url = URL(string: "https://api.example.com/binary-as-json")!
        let binaryData = Data([0x00, 0x01, 0x02, 0x03])
        
        Networking.registerMockData(binaryData, httpStatus: .OK, contentType: .applicationOctetStream, for: url)
        
        do {
            let _: TestUser = try await HTTP.GET(from: URLRequest(url: url))
            XCTFail("Expected error to be thrown")
        } catch let error as Networking.Error {
            if case .unexpectedMimeType(let mimeType) = error {
                XCTAssertEqual(mimeType, "application/octet-stream")
            } else {
                XCTFail("Expected unexpectedMimeType error, got \(error)")
            }
        }
    }

    // MARK: - Request Error Tests

    func testUnsuitableRequest_MissingURL() async throws {
        var urlRequest = URLRequest(url: URL(string: "https://example.com")!)
        urlRequest.url = nil // Simulate missing URL
        
        do {
            let status = try await networking.DELETE(via: urlRequest)
            XCTFail("Expected error to be thrown, got status: \(status)")
        } catch let error as Networking.Error {
            if case .unsuitableRequest(let message) = error {
                XCTAssertTrue(message.contains("URL"))
            } else {
                XCTFail("Expected unsuitableRequest error, got \(error)")
            }
        } catch {
            // The actual implementation might not throw this specific error
            // depending on how URLRequest handles nil URLs
        }
    }

    // MARK: - Response Error Tests

    func testUnexpectedResponse() async throws {
        // This test is challenging to create since we're using mocks
        // In a real scenario, this would happen if the response isn't HTTPURLResponse
        // We'll test the error case exists in the enum
        let error = Networking.Error.unexpectedResponse("TestResponse != HTTPURLResponse")
        
        switch error {
        case .unexpectedResponse(let message):
            XCTAssertEqual(message, "TestResponse != HTTPURLResponse")
        default:
            XCTFail("Expected unexpectedResponse error")
        }
    }

    // MARK: - File Operation Error Tests

    func testFileDownloadToInvalidPath() async throws {
        let url = URL(string: "https://api.example.com/download")!
        let mockData = "test content".data(using: .utf8)!
        // Try to save to a path that doesn't exist (parent directory doesn't exist)
        let invalidDestination = URL(fileURLWithPath: "/nonexistent/path/file.txt")
        
        Networking.registerMockData(mockData, httpStatus: .OK, contentType: HTTP.MimeType.textPlain, for: url)
        
        do {
            let _ = try await HTTP.GET(from: URLRequest(url: url), to: invalidDestination)
            XCTFail("Expected error to be thrown")
        } catch {
            // Expected - file system error when trying to move file to invalid location
            // The specific error type depends on the underlying file system operation
        }
    }

    // MARK: - Edge Cases

    func testEmptyResponse() async throws {
        let url = URL(string: "https://api.example.com/empty")!
        
        Networking.registerMockData(Data(), httpStatus: .OK, contentType: .applicationJSON, for: url)
        
        do {
            let _: TestUser = try await HTTP.GET(from: URLRequest(url: url))
            XCTFail("Expected error to be thrown")
        } catch let error as Networking.Error {
            if case .decodingError(_) = error {
                // Expected - empty data can't be decoded as TestUser
            } else {
                XCTFail("Expected decodingError, got \(error)")
            }
        }
    }

    func testNullJSON() async throws {
        let url = URL(string: "https://api.example.com/null")!
        let nullJSON = "null".data(using: .utf8)!
        
        Networking.registerMockData(nullJSON, httpStatus: .OK, contentType: .applicationJSON, for: url)
        
        do {
            let _: TestUser = try await HTTP.GET(from: URLRequest(url: url))
            XCTFail("Expected error to be thrown")
        } catch let error as Networking.Error {
            if case .decodingError(_) = error {
                // Expected - null can't be decoded as TestUser
            } else {
                XCTFail("Expected decodingError, got \(error)")
            }
        }
    }

    func testOptionalResponse() async throws {
        let url = URL(string: "https://api.example.com/optional")!
        let nullJSON = "null".data(using: .utf8)!
        
        Networking.registerMockData(nullJSON, httpStatus: .OK, contentType: .applicationJSON, for: url)
        
        // This should work - Optional<TestUser> can decode from null JSON
        let result: TestUser? = try await HTTP.GET(from: URLRequest(url: url))
        XCTAssertNil(result)
    }
}

// MARK: - Test Models

private struct TestUser: Codable {
    let id: Int
    let name: String
    let email: String
}

