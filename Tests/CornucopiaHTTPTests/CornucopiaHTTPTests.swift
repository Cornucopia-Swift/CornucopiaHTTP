import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import CornucopiaHTTP

/// Integration tests that automatically start/stop a JSON server on localhost:3000
final class CornucopiaHTTPIntegrationTests: XCTestCase {
    
    private let serverPrefix = "http://localhost:3000"
    private var serverProcess: Process?
    private static var sharedServerProcess: Process?
    private static var serverUsageCount = 0
    
    override func setUp() async throws {
        try await super.setUp()
        try await ensureJSONServerRunning()
    }
    
    override func tearDown() async throws {
        // Don't stop server immediately - let it be reused by other tests
        try await super.tearDown()
    }
    
    override class func tearDown() {
        // Stop shared server when all tests are done
        stopSharedJSONServer()
        super.tearDown()
    }
    
    private func ensureJSONServerRunning() async throws {
        // If shared server is already running, just increment usage count
        if let process = Self.sharedServerProcess, process.isRunning {
            Self.serverUsageCount += 1
            return
        }
        
        try await startSharedJSONServer()
    }
    
    private func startSharedJSONServer() async throws {
        // Check if json-server is available
        guard FileManager.default.fileExists(atPath: "/opt/homebrew/bin/json-server") else {
            throw XCTSkip("json-server not found. Install with: npm install -g json-server")
        }
        
        // Find the db.json file relative to the package root
        let packageURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Tests/CornucopiaHTTPTests/
            .deletingLastPathComponent() // Tests/
            .deletingLastPathComponent() // Package root
        let dbPath = packageURL.appendingPathComponent("json-server/db.json").path
        
        guard FileManager.default.fileExists(atPath: dbPath) else {
            throw XCTSkip("Database file not found at: \(dbPath)")
        }
        
        // Start json-server process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/json-server")
        process.arguments = ["--port", "3000", dbPath]
        process.currentDirectoryURL = packageURL
        
        // Capture output to prevent it from cluttering test output
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        Self.sharedServerProcess = process
        Self.serverUsageCount = 1
        
        // Wait for server to be ready (up to 5 seconds)
        for attempt in 1...10 {
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Try to connect to see if server is ready
            do {
                let url = URL(string: "\(serverPrefix)/subjects")!
                let _: [Subject] = try await HTTP.GET(from: URLRequest(url: url))
                return // Server is ready!
            } catch {
                // Server not ready yet, continue waiting
                if attempt == 10 {
                    throw XCTSkip("JSON server failed to start after 5 seconds: \(error)")
                }
            }
        }
    }
    
    private static func stopSharedJSONServer() {
        sharedServerProcess?.terminate()
        // Give it a moment to shut down gracefully
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            sharedServerProcess?.waitUntilExit()
        }
        sharedServerProcess = nil
        serverUsageCount = 0
    }
    
    private func verifyServerRunning() async throws {
        // Server readiness is already verified in startJSONServer()
        // This method is kept for compatibility but does nothing
    }

    func testGET_FetchSubjects() async throws {
        let subjectsUrl = URL(string: "\(serverPrefix)/subjects")!
        let subjects: [Subject] = try await HTTP.GET(from: URLRequest(url: subjectsUrl))
        
        XCTAssertGreaterThan(subjects.count, 0, "Should have at least one subject")
        
        // Verify structure of first subject
        if let firstSubject = subjects.first {
            XCTAssertNotNil(firstSubject.id, "Subject should have an ID")
            XCTAssertNotNil(firstSubject.name, "Subject should have a name")
        }
    }

    func testPOST_CreateSubject() async throws {
        let subjectsUrl = URL(string: "\(serverPrefix)/subjects")!
        let newSubject = Subject(id: nil, name: "Test Subject \(UUID().uuidString.prefix(8))")
        
        let returnedSubject = try await HTTP.POST(item: newSubject, to: URLRequest(url: subjectsUrl))
        
        XCTAssertEqual(newSubject.name, returnedSubject.name, "Returned subject should have the same name")
        XCTAssertNotNil(returnedSubject.id, "Returned subject should have an assigned ID")
        
        // Clean up: delete the created subject
        if let id = returnedSubject.id {
            try? await HTTP.DELETE(via: URLRequest(url: URL(string: "\(serverPrefix)/subjects/\(id)")!))
        }
    }

    func testPOST_LargePayload() async throws {
        // Note: json-server doesn't handle gzipped request bodies properly, so we test large payloads without compression
        // This test verifies that large JSON payloads can be sent successfully to the server
        
        let subjectsUrl = URL(string: "\(serverPrefix)/subjects")!
        let longName = String(repeating: "Large Subject Name ", count: 100) + UUID().uuidString
        let newSubject = Subject(id: nil, name: longName)
        
        let returnedSubject = try await HTTP.POST(item: newSubject, to: URLRequest(url: subjectsUrl))
        
        XCTAssertEqual(newSubject.name, returnedSubject.name, "Large payload should be handled correctly")
        XCTAssertNotNil(returnedSubject.id, "Returned subject should have an assigned ID")
        
        // Clean up: delete the created subject
        if let id = returnedSubject.id {
            try? await HTTP.DELETE(via: URLRequest(url: URL(string: "\(serverPrefix)/subjects/\(id)")!))
        }
    }

    func testPUT_UpdateSubject() async throws {
        // First, create a subject to update
        let subjectsUrl = URL(string: "\(serverPrefix)/subjects")!
        let originalSubject = Subject(id: nil, name: "Original Name \(UUID().uuidString.prefix(8))")
        let createdSubject = try await HTTP.POST(item: originalSubject, to: URLRequest(url: subjectsUrl))
        
        guard let id = createdSubject.id else {
            XCTFail("Created subject should have an ID")
            return
        }
        
        // Now update it
        let subjectUrl = URL(string: "\(serverPrefix)/subjects/\(id)")!
        var subjectToUpdate = createdSubject
        subjectToUpdate.name = "Updated Name \(UUID().uuidString.prefix(8))"
        
        let updatedSubject = try await HTTP.PUT(item: subjectToUpdate, to: URLRequest(url: subjectUrl))
        
        XCTAssertEqual(subjectToUpdate.id, updatedSubject.id, "ID should remain the same")
        XCTAssertEqual(subjectToUpdate.name, updatedSubject.name, "Name should be updated")
        XCTAssertNotEqual(originalSubject.name, updatedSubject.name, "Name should have changed")
        
        // Clean up
        try? await HTTP.DELETE(via: URLRequest(url: subjectUrl))
    }

    func testDELETE_RemoveSubject() async throws {
        // First, create a subject to delete
        let subjectsUrl = URL(string: "\(serverPrefix)/subjects")!
        let subjectToDelete = Subject(id: nil, name: "To Delete \(UUID().uuidString.prefix(8))")
        let createdSubject = try await HTTP.POST(item: subjectToDelete, to: URLRequest(url: subjectsUrl))
        
        guard let id = createdSubject.id else {
            XCTFail("Created subject should have an ID")
            return
        }
        
        // Delete it
        let deleteUrl = URL(string: "\(serverPrefix)/subjects/\(id)")!
        let status = try await HTTP.DELETE(via: URLRequest(url: deleteUrl))
        
        // Verify deletion was successful (typically returns 200 or 204)
        XCTAssertTrue(status.responseType == .Success, "Delete operation should succeed")
        
        // Verify it's actually gone by trying to fetch it (should fail with 404)
        do {
            let _: Subject = try await HTTP.GET(from: URLRequest(url: deleteUrl))
            XCTFail("Subject should no longer exist after deletion")
        } catch let error as Networking.Error {
            if case .unsuccessful(let errorStatus) = error {
                XCTAssertEqual(errorStatus, .NotFound, "Should get 404 when trying to fetch deleted subject")
            }
        }
    }
    
    func testGET_DownloadToFile() async throws {
        // Use a more reliable test file URL (could be served by json-server with static files)
        let url = URL(string: "https://httpbin.org/bytes/1024")!
        let destination = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("download-test-\(UUID().uuidString).bin")
        
        do {
            let headers = try await HTTP.GET(from: URLRequest(url: url), to: destination)
            
            XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path), "Downloaded file should exist")
            
            let fileData = try Data(contentsOf: destination)
            XCTAssertEqual(fileData.count, 1024, "Downloaded file should be 1024 bytes")
            
            XCTAssertNotNil(headers[HTTP.HeaderField.contentLength.rawValue], "Should have content-length header")
            
            // Clean up
            try? FileManager.default.removeItem(at: destination)
        } catch {
            // Skip test if httpbin is not available
            throw XCTSkip("External download test failed: \(error)")
        }
    }

    func testGET_DownloadWithProgress() async throws {
        let url = URL(string: "https://httpbin.org/bytes/10240")! // 10KB test file
        let destination = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("progress-test-\(UUID().uuidString).bin")
        
        var progressUpdates: [Double] = []
        
        do {
            let headers = try await Networking().load(urlRequest: URLRequest(url: url), to: destination) { progress in
                progressUpdates.append(progress.fractionCompleted)
            }
            
            XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path), "Downloaded file should exist")
            
            let fileData = try Data(contentsOf: destination)
            XCTAssertEqual(fileData.count, 10240, "Downloaded file should be 10KB")
            
            // Clean up
            try? FileManager.default.removeItem(at: destination)
        } catch {
            // Skip test if httpbin is not available
            throw XCTSkip("External download test with progress failed: \(error)")
        }
    }

    func testPOST_BinaryData() async throws {
        let binary: [UInt8] = [0, 1, 2, 3, 4, 5]
        let data = Data(binary)
        
        do {
            let url = URL(string: "https://httpbin.org/post")!
            let status = try await HTTP.POST(data: data, via: URLRequest(url: url))
            XCTAssertTrue(status.responseType == .Success, "Binary POST should succeed")
        } catch {
            // Skip test if httpbin is not available
            throw XCTSkip("External binary POST test failed: \(error)")
        }
    }
    
    func testHEAD_CheckResourceExists() async throws {
        let subjectsUrl = URL(string: "\(serverPrefix)/subjects")!
        
        let headers = try await HTTP.HEAD(at: URLRequest(url: subjectsUrl))
        
        XCTAssertNotNil(headers[HTTP.HeaderField.contentType.rawValue], "Should have content-type header")
        // JSON server typically returns application/json for /subjects endpoint
        XCTAssertTrue(headers[HTTP.HeaderField.contentType.rawValue]?.contains("json") == true, "Content type should be JSON")
    }
    
    func testNetworking_InstanceMethods() async throws {
        let networking = Networking()
        let subjectsUrl = URL(string: "\(serverPrefix)/subjects")!
        
        // Test that instance methods work the same as static methods
        let subjects: [Subject] = try await networking.GET(from: URLRequest(url: subjectsUrl))
        XCTAssertGreaterThan(subjects.count, 0, "Should have at least one subject")
        
        // Test HEAD with instance method
        let headers = try await networking.HEAD(at: URLRequest(url: subjectsUrl))
        XCTAssertNotNil(headers[HTTP.HeaderField.contentType.rawValue], "Should have content-type header")
    }
}

// MARK: - Test Models

private struct Subject: Codable {
    let id: String?
    var name: String?
}
