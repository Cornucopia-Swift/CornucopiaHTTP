import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import CornucopiaHTTP

final class CompressionTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        // Clear any existing compression settings
        Networking.disableCompressedUploads(for: "test")
    }

    override func tearDown() async throws {
        // Clean up compression settings
        Networking.disableCompressedUploads(for: "test")
        try await super.tearDown()
    }

    // MARK: - Compression Configuration Tests

    func testEnableCompressedUploads() {
        let regex = try! Regex("https://api\\.example\\.com/.*") as Regex<Substring>
        
        Networking.enableCompressedUploads(for: regex, key: "test")
        
        let url = URL(string: "https://api.example.com/users")!
        let shouldCompress = Networking.shouldCompressUpload(urlRequest: URLRequest(url: url))
        
        XCTAssertTrue(shouldCompress)
    }

    func testDisableCompressedUploads() {
        let regex = try! Regex("https://api\\.example\\.com/.*") as Regex<Substring>
        
        // Enable first
        Networking.enableCompressedUploads(for: regex, key: "test")
        
        let url = URL(string: "https://api.example.com/users")!
        XCTAssertTrue(Networking.shouldCompressUpload(urlRequest: URLRequest(url: url)))
        
        // Then disable
        Networking.disableCompressedUploads(for: "test")
        XCTAssertFalse(Networking.shouldCompressUpload(urlRequest: URLRequest(url: url)))
    }

    func testShouldCompressUpload_NoMatch() {
        let regex = try! Regex("https://api\\.example\\.com/.*") as Regex<Substring>
        Networking.enableCompressedUploads(for: regex, key: "test")
        
        let url = URL(string: "https://other.example.com/users")!
        let shouldCompress = Networking.shouldCompressUpload(urlRequest: URLRequest(url: url))
        
        XCTAssertFalse(shouldCompress)
    }

    func testShouldCompressUpload_MultipleRules() {
        let regex1 = try! Regex("https://api\\.example\\.com/.*") as Regex<Substring>
        let regex2 = try! Regex("https://upload\\.service\\.com/.*") as Regex<Substring>
        
        Networking.enableCompressedUploads(for: regex1, key: "api")
        Networking.enableCompressedUploads(for: regex2, key: "upload")
        
        let url1 = URL(string: "https://api.example.com/users")!
        let url2 = URL(string: "https://upload.service.com/files")!
        let url3 = URL(string: "https://other.com/data")!
        
        XCTAssertTrue(Networking.shouldCompressUpload(urlRequest: URLRequest(url: url1)))
        XCTAssertTrue(Networking.shouldCompressUpload(urlRequest: URLRequest(url: url2)))
        XCTAssertFalse(Networking.shouldCompressUpload(urlRequest: URLRequest(url: url3)))
        
        // Clean up
        Networking.disableCompressedUploads(for: "api")
        Networking.disableCompressedUploads(for: "upload")
    }

    func testShouldCompressUpload_MissingURL() {
        let regex = try! Regex("https://.*") as Regex<Substring>
        Networking.enableCompressedUploads(for: regex, key: "test")
        
        var urlRequest = URLRequest(url: URL(string: "https://example.com")!)
        urlRequest.url = nil
        
        let shouldCompress = Networking.shouldCompressUpload(urlRequest: urlRequest)
        XCTAssertFalse(shouldCompress)
    }

    // MARK: - Compression Integration Tests

    func testPOST_WithCompression() async throws {
        // Enable compression for our test URL
        let regex = try! Regex("https://api\\.example\\.com/.*") as Regex<Substring>
        Networking.enableCompressedUploads(for: regex, key: "test")
        
        let url = URL(string: "https://api.example.com/large-data")!
        
        // Create a large payload that would benefit from compression
        let largePayload = LargeTestPayload(
            data: String(repeating: "This is a large string that should compress well. ", count: 100),
            numbers: Array(1...1000),
            metadata: LargeTestPayload.Metadata(
                description: String(repeating: "Metadata description with lots of repeated text. ", count: 50),
                tags: Array(repeating: "tag", count: 100)
            )
        )
        
        let responseData = """
        {"id": 123, "status": "processed"}
        """.data(using: .utf8)!
        
        Networking.registerMockData(responseData, httpStatus: .Created, contentType: .applicationJSON, for: url)
        
        let result: ProcessedResponse = try await HTTP.POST(item: largePayload, to: URLRequest(url: url))
        XCTAssertEqual(result.id, 123)
        XCTAssertEqual(result.status, "processed")
    }

    func testPOST_WithoutCompression() async throws {
        // Ensure compression is disabled for this URL
        let url = URL(string: "https://no-compression.example.com/data")!
        
        let payload = SimpleTestPayload(message: "Hello", value: 42)
        let responseData = """
        {"id": 456, "status": "received"}
        """.data(using: .utf8)!
        
        Networking.registerMockData(responseData, httpStatus: .Created, contentType: .applicationJSON, for: url)
        
        let result: ProcessedResponse = try await HTTP.POST(item: payload, to: URLRequest(url: url))
        XCTAssertEqual(result.id, 456)
        XCTAssertEqual(result.status, "received")
    }

    func testPUT_WithCompression() async throws {
        let regex = try! Regex("https://api\\.example\\.com/.*") as Regex<Substring>
        Networking.enableCompressedUploads(for: regex, key: "test")
        
        let url = URL(string: "https://api.example.com/documents/123")!
        
        let document = DocumentPayload(
            title: "Large Document",
            content: String(repeating: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. ", count: 200),
            tags: Array(repeating: "documentation", count: 50)
        )
        
        let responseData = """
        {
            "title": "Large Document",
            "content": "\(document.content)",
            "tags": \(try! String(data: JSONEncoder().encode(document.tags), encoding: .utf8)!)
        }
        """.data(using: .utf8)!
        
        Networking.registerMockData(responseData, httpStatus: .OK, contentType: .applicationJSON, for: url)
        
        let result: DocumentPayload = try await HTTP.PUT(item: document, to: URLRequest(url: url))
        XCTAssertEqual(result.title, "Large Document")
        XCTAssertEqual(result.content, document.content)
    }

    func testPATCH_WithCompression() async throws {
        let regex = try! Regex("https://api\\.example\\.com/.*") as Regex<Substring>
        Networking.enableCompressedUploads(for: regex, key: "test")
        
        let url = URL(string: "https://api.example.com/profiles/123")!
        
        let profileUpdate = ProfileUpdatePayload(
            bio: String(repeating: "Updated bio with lots of text that should compress well. ", count: 100),
            interests: Array(repeating: "interest", count: 200)
        )
        
        let responseData = """
        {
            "id": 123,
            "bio": "\(profileUpdate.bio)",
            "interests": \(try! String(data: JSONEncoder().encode(profileUpdate.interests), encoding: .utf8)!)
        }
        """.data(using: .utf8)!
        
        Networking.registerMockData(responseData, httpStatus: .OK, contentType: .applicationJSON, for: url)
        
        let result: ProfileResponse = try await HTTP.PATCH(item: profileUpdate, to: URLRequest(url: url))
        XCTAssertEqual(result.id, 123)
        XCTAssertEqual(result.bio, profileUpdate.bio)
    }

    // MARK: - Edge Cases

    func testCompressionWithSmallPayload() async throws {
        let regex = try! Regex("https://api\\.example\\.com/.*") as Regex<Substring>
        Networking.enableCompressedUploads(for: regex, key: "test")
        
        let url = URL(string: "https://api.example.com/small")!
        
        // Small payload that might not benefit from compression
        let smallPayload = SimpleTestPayload(message: "Hi", value: 1)
        let responseData = """
        {"id": 1, "status": "ok"}
        """.data(using: .utf8)!
        
        Networking.registerMockData(responseData, httpStatus: .Created, contentType: .applicationJSON, for: url)
        
        let result: ProcessedResponse = try await HTTP.POST(item: smallPayload, to: URLRequest(url: url))
        XCTAssertEqual(result.id, 1)
        XCTAssertEqual(result.status, "ok")
    }

    func testCompressionRegexPatterns() {
        // Test various regex patterns
        let patterns = [
            ("https://api\\.example\\.com/.*", "https://api.example.com/users", true),
            ("https://api\\.example\\.com/users", "https://api.example.com/users", true),
            ("https://api\\.example\\.com/users", "https://api.example.com/posts", false),
            (".*\\.json", "https://example.com/data.json", true),
            (".*\\.json", "https://example.com/data.xml", false),
            ("https://.*", "http://example.com", false),
            ("https://.*", "https://example.com", true)
        ]
        
        for (index, (pattern, url, expected)) in patterns.enumerated() {
            let key = "test-\(index)"
            let regex = try! Regex(pattern) as Regex<Substring>
            
            Networking.enableCompressedUploads(for: regex, key: key)
            
            let urlRequest = URLRequest(url: URL(string: url)!)
            let shouldCompress = Networking.shouldCompressUpload(urlRequest: urlRequest)
            
            XCTAssertEqual(shouldCompress, expected, "Pattern '\(pattern)' with URL '\(url)' should return \(expected)")
            
            Networking.disableCompressedUploads(for: key)
        }
    }
}

// MARK: - Test Models

private struct LargeTestPayload: Codable {
    let data: String
    let numbers: [Int]
    let metadata: Metadata
    
    struct Metadata: Codable {
        let description: String
        let tags: [String]
    }
}

private struct SimpleTestPayload: Codable {
    let message: String
    let value: Int
}

private struct ProcessedResponse: Codable {
    let id: Int
    let status: String
}

private struct DocumentPayload: Codable {
    let title: String
    let content: String
    let tags: [String]
}

private struct ProfileUpdatePayload: Codable {
    let bio: String
    let interests: [String]
}

private struct ProfileResponse: Codable {
    let id: Int
    let bio: String
    let interests: [String]
}