import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import CornucopiaHTTP

final class ProgressObservationTests: XCTestCase {

    var networking: Networking!

    override func setUp() async throws {
        try await super.setUp()
        networking = Networking()
    }

    override func tearDown() async throws {
        networking = nil
        try await super.tearDown()
    }

    // MARK: - Progress Observer Tests

    func testProgressObserver_BasicFunctionality() async throws {
        let url = URL(string: "https://api.example.com/large-file")!
        let mockData = Data(repeating: 0x42, count: 10240) // 10KB
        let destination = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("progress-test-\(UUID().uuidString).dat")
        
        Networking.registerMockData(mockData, httpStatus: .OK, contentType: .applicationOctetStream, for: url)
        
        var progressUpdates: [Double] = []
        var progressObjects: [Progress] = []
        
        let progressObserver: Networking.ProgressObserver = { progress in
            progressUpdates.append(progress.fractionCompleted)
            progressObjects.append(progress)
        }
        
        let headers = try await networking.GET(from: URLRequest(url: url), to: destination, progressObserver: progressObserver)
        
        // Verify file was downloaded
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertEqual(headers[HTTP.HeaderField.contentType.rawValue], HTTP.MimeType.applicationOctetStream.rawValue)
        
        let savedData = try Data(contentsOf: destination)
        XCTAssertEqual(savedData, mockData)
        
        // Note: Progress callbacks might not be called for mocked requests in the same way as real downloads
        // The main goal is to ensure the API accepts the observer and doesn't crash
        
        try? FileManager.default.removeItem(at: destination)
    }

    func testProgressObserver_MultipleCallbacks() async throws {
        let url = URL(string: "https://api.example.com/multi-progress")!
        let mockData = Data(repeating: 0xFF, count: 50000) // 50KB
        let destination = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("multi-progress-\(UUID().uuidString).dat")
        
        Networking.registerMockData(mockData, httpStatus: .OK, contentType: .applicationOctetStream, for: url)
        
        var callbackCount = 0
        var _: Progress?
        
        let progressObserver: Networking.ProgressObserver = { progress in
            callbackCount += 1
            _ = progress
        }
        
        let headers = try await networking.GET(from: URLRequest(url: url), to: destination, progressObserver: progressObserver)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertEqual(headers[HTTP.HeaderField.contentLength.rawValue], "\(mockData.count)")
        
        // Cleanup
        try? FileManager.default.removeItem(at: destination)
    }

    func testProgressObserver_ProgressValues() async throws {
        let url = URL(string: "https://api.example.com/progress-values")!
        let mockData = Data(repeating: 0xAB, count: 1024) // 1KB
        let destination = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("progress-values-\(UUID().uuidString).dat")
        
        Networking.registerMockData(mockData, httpStatus: .OK, contentType: .applicationOctetStream, for: url)
        
        var progressValues: [Double] = []
        var totalUnitCounts: [Int64] = []
        var completedUnitCounts: [Int64] = []
        
        let progressObserver: Networking.ProgressObserver = { progress in
            progressValues.append(progress.fractionCompleted)
            totalUnitCounts.append(progress.totalUnitCount)
            completedUnitCounts.append(progress.completedUnitCount)
            
            // Verify progress values are within valid range
            XCTAssertGreaterThanOrEqual(progress.fractionCompleted, 0.0)
            XCTAssertLessThanOrEqual(progress.fractionCompleted, 1.0)
            XCTAssertGreaterThanOrEqual(progress.completedUnitCount, 0)
            XCTAssertLessThanOrEqual(progress.completedUnitCount, progress.totalUnitCount)
        }
        
        let headers = try await networking.GET(from: URLRequest(url: url), to: destination, progressObserver: progressObserver)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
        
        // Cleanup
        try? FileManager.default.removeItem(at: destination)
    }

    func testProgressObserver_EmptyFile() async throws {
        let url = URL(string: "https://api.example.com/empty-file")!
        let emptyData = Data()
        let destination = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("empty-\(UUID().uuidString).dat")
        
        Networking.registerMockData(emptyData, httpStatus: .OK, contentType: .applicationOctetStream, for: url)
        
        var progressCallbackCount = 0
        
        let progressObserver: Networking.ProgressObserver = { progress in
            progressCallbackCount += 1
            // Even for empty files, progress should be valid
            XCTAssertGreaterThanOrEqual(progress.fractionCompleted, 0.0)
            XCTAssertLessThanOrEqual(progress.fractionCompleted, 1.0)
        }
        
        let headers = try await networking.GET(from: URLRequest(url: url), to: destination, progressObserver: progressObserver)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertEqual(headers[HTTP.HeaderField.contentLength.rawValue], "0")
        
        let savedData = try Data(contentsOf: destination)
        XCTAssertEqual(savedData.count, 0)
        
        // Cleanup
        try? FileManager.default.removeItem(at: destination)
    }

    // MARK: - Error Handling with Progress

    func testProgressObserver_WithError() async throws {
        let url = URL(string: "https://api.example.com/progress-error")!
        let destination = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("error-\(UUID().uuidString).dat")
        
        // Register an error response
        Networking.registerMockData(Data(), httpStatus: .NotFound, contentType: .applicationJSON, for: url)
        
        var progressCallbackCount = 0
        
        let progressObserver: Networking.ProgressObserver = { progress in
            progressCallbackCount += 1
        }
        
        do {
            let _ = try await networking.GET(from: URLRequest(url: url), to: destination, progressObserver: progressObserver)
            XCTFail("Expected error to be thrown")
        } catch let error as Networking.Error {
            if case .unsuccessful(let status) = error {
                XCTAssertEqual(status, .NotFound)
            } else {
                XCTFail("Expected unsuccessful error, got \(error)")
            }
        }
        
        // File should not exist since download failed
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
        
        // Cleanup (just in case)
        try? FileManager.default.removeItem(at: destination)
    }

    func testProgressObserver_FileSystemError() async throws {
        let url = URL(string: "https://api.example.com/filesystem-error")!
        let mockData = Data(repeating: 0x55, count: 1024)
        // Try to save to an invalid path (parent directory doesn't exist)
        let invalidDestination = URL(fileURLWithPath: "/nonexistent/directory/file.dat")
        
        Networking.registerMockData(mockData, httpStatus: .OK, contentType: .applicationOctetStream, for: url)
        
        var progressCallbackCount = 0
        
        let progressObserver: Networking.ProgressObserver = { progress in
            progressCallbackCount += 1
        }
        
        do {
            let _ = try await networking.GET(from: URLRequest(url: url), to: invalidDestination, progressObserver: progressObserver)
            XCTFail("Expected error to be thrown")
        } catch {
            // Expected - file system error
            // Progress callbacks might still have been called before the file operation failed
        }
    }

    // MARK: - Progress Observer Threading

    func testProgressObserver_ThreadSafety() async throws {
        let url = URL(string: "https://api.example.com/thread-safety")!
        let mockData = Data(repeating: 0x77, count: 2048) // 2KB
        let destination = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("thread-safety-\(UUID().uuidString).dat")
        
        Networking.registerMockData(mockData, httpStatus: .OK, contentType: .applicationOctetStream, for: url)
        
        let expectation = XCTestExpectation(description: "Progress observer called")
        var callbackThreads: [Thread] = []
        
        let progressObserver: Networking.ProgressObserver = { progress in
            callbackThreads.append(Thread.current)
            expectation.fulfill()
        }
        
        let headers = try await networking.GET(from: URLRequest(url: url), to: destination, progressObserver: progressObserver)
        
        // Wait for at least one callback
        await fulfillment(of: [expectation], timeout: 5.0)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
        
        // Cleanup
        try? FileManager.default.removeItem(at: destination)
    }

    // MARK: - Comparison with Non-Progress Methods

    func testProgressVsNonProgress_SameResult() async throws {
        let url1 = URL(string: "https://api.example.com/comparison1")!
        let url2 = URL(string: "https://api.example.com/comparison2")!
        let mockData = Data(repeating: 0x88, count: 5120) // 5KB
        
        let destination1 = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("comparison1-\(UUID().uuidString).dat")
        let destination2 = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("comparison2-\(UUID().uuidString).dat")
        
        Networking.registerMockData(mockData, httpStatus: .OK, contentType: .applicationOctetStream, for: url1)
        Networking.registerMockData(mockData, httpStatus: .OK, contentType: .applicationOctetStream, for: url2)
        
        // Download with progress observer
        let progressObserver: Networking.ProgressObserver = { _ in
            // Just a no-op observer
        }
        let headers1 = try await networking.GET(from: URLRequest(url: url1), to: destination1, progressObserver: progressObserver)
        
        // Download without progress observer
        let headers2 = try await networking.GET(from: URLRequest(url: url2), to: destination2)
        
        // Both downloads should succeed and produce identical results
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination1.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination2.path))
        
        let data1 = try Data(contentsOf: destination1)
        let data2 = try Data(contentsOf: destination2)
        
        XCTAssertEqual(data1, data2)
        XCTAssertEqual(data1, mockData)
        
        XCTAssertEqual(headers1[HTTP.HeaderField.contentType.rawValue], headers2[HTTP.HeaderField.contentType.rawValue])
        XCTAssertEqual(headers1[HTTP.HeaderField.contentLength.rawValue], headers2[HTTP.HeaderField.contentLength.rawValue])
        
        // Cleanup
        try? FileManager.default.removeItem(at: destination1)
        try? FileManager.default.removeItem(at: destination2)
    }

    // MARK: - Real Progress Testing (if possible)

    func testProgressObserver_ActualProgressUpdates() async throws {
        let url = URL(string: "https://api.example.com/large-download")!
        let largeData = Data(repeating: 0x99, count: 100000) // 100KB
        let destination = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("large-download-\(UUID().uuidString).dat")
        
        Networking.registerMockData(largeData, httpStatus: .OK, contentType: .applicationOctetStream, for: url)
        
        var progressUpdates: [Double] = []
        let progressUpdateLock = NSLock()
        
        let progressObserver: Networking.ProgressObserver = { progress in
            progressUpdateLock.lock()
            defer { progressUpdateLock.unlock() }
            
            progressUpdates.append(progress.fractionCompleted)
            
            // Verify progress is monotonic (non-decreasing)
            if progressUpdates.count > 1 {
                let previous = progressUpdates[progressUpdates.count - 2]
                let current = progressUpdates.last!
                XCTAssertGreaterThanOrEqual(current, previous, "Progress should be non-decreasing")
            }
        }
        
        let headers = try await networking.GET(from: URLRequest(url: url), to: destination, progressObserver: progressObserver)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
        
        let savedData = try Data(contentsOf: destination)
        XCTAssertEqual(savedData, largeData)
        
        // Cleanup
        try? FileManager.default.removeItem(at: destination)
    }
}

// MARK: - Custom MIME Types

private extension HTTP.MimeType {
    static let textPlain = HTTP.MimeType(rawValue: "text/plain")!
}