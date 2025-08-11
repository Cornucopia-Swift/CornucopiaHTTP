import Foundation
@testable import CornucopiaHTTP

/// Test helpers and utilities for CornucopiaHTTP test suites
enum TestHelpers {
    
    /// Generates test URLs with unique identifiers to avoid mock collisions
    static func uniqueTestURL(path: String = "test") -> URL {
        return URL(string: "https://test.example.com/\(path)/\(UUID().uuidString)")!
    }
    
    /// Creates a temporary file URL in the system temp directory
    static func temporaryFileURL(extension ext: String = "tmp") -> URL {
        let filename = "test-\(UUID().uuidString).\(ext)"
        return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(filename)
    }
    
    /// Cleans up a temporary file if it exists
    static func cleanupFile(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
    
    /// Creates test data of specified size
    static func generateTestData(size: Int, pattern: UInt8 = 0xFF) -> Data {
        return Data(repeating: pattern, count: size)
    }
    
    /// Creates JSON data from a Codable object
    static func jsonData<T: Codable>(from object: T) throws -> Data {
        return try JSONEncoder().encode(object)
    }
    
    /// Creates a mock HTTPURLResponse for testing
    static func createMockResponse(
        url: URL,
        statusCode: Int = 200,
        headers: [String: String] = [:]
    ) -> HTTPURLResponse? {
        return HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )
    }
    
    /// Registers a JSON mock for a given URL
    static func registerJSONMock<T: Codable>(
        object: T,
        for url: URL,
        status: HTTP.Status = .OK
    ) throws {
        let jsonData = try jsonData(from: object)
        Networking.registerMockData(
            jsonData,
            httpStatus: status,
            contentType: .applicationJSON,
            for: url
        )
    }
    
    /// Registers an error mock for a given URL
    static func registerErrorMock(
        for url: URL,
        status: HTTP.Status,
        errorDetails: [String: Any]? = nil
    ) throws {
        let data: Data
        if let errorDetails = errorDetails {
            data = try JSONSerialization.data(withJSONObject: errorDetails)
        } else {
            data = Data()
        }
        
        Networking.registerMockData(
            data,
            httpStatus: status,
            contentType: .applicationJSON,
            for: url
        )
    }
    
    /// Waits for a condition to be true with timeout
    static func waitForCondition(
        timeout: TimeInterval = 5.0,
        condition: () -> Bool
    ) async throws {
        let start = Date()
        while !condition() {
            if Date().timeIntervalSince(start) > timeout {
                throw TestError.timeout
            }
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
    }
    
    /// Test-specific errors
    enum TestError: Error {
        case timeout
        case mockSetupFailed
        case unexpectedResult
    }
}

/// Common test data structures
extension TestHelpers {
    
    struct TestUser: Codable, Equatable {
        let id: Int?
        let name: String
        let email: String
        
        init(id: Int? = nil, name: String, email: String) {
            self.id = id
            self.name = name
            self.email = email
        }
    }
    
    struct TestErrorResponse: Codable {
        let error: String
        let message: String
        let code: String
    }
    
    struct TestResponse: Codable {
        let success: Bool
        let data: [String: String]?
        let message: String?
    }
    
    struct LargeTestObject: Codable {
        let id: String
        let data: String
        let metadata: [String: String]
        let numbers: [Int]
        
        init(size: Int = 1000) {
            self.id = UUID().uuidString
            self.data = String(repeating: "Lorem ipsum dolor sit amet. ", count: size)
            self.metadata = Dictionary(uniqueKeysWithValues: (1...10).map { ("key\($0)", "value\($0)") })
            self.numbers = Array(1...size)
        }
    }
}

/// Progress tracking helper for tests
class ProgressTracker {
    private var _progressUpdates: [Double] = []
    private var _progressObjects: [Progress] = []
    private let lock = NSLock()
    
    var progressUpdates: [Double] {
        lock.lock()
        defer { lock.unlock() }
        return _progressUpdates
    }
    
    var progressObjects: [Progress] {
        lock.lock()
        defer { lock.unlock() }
        return _progressObjects
    }
    
    var callCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _progressUpdates.count
    }
    
    func makeObserver() -> Networking.ProgressObserver {
        return { [weak self] progress in
            self?.recordProgress(progress)
        }
    }
    
    private func recordProgress(_ progress: Progress) {
        lock.lock()
        defer { lock.unlock() }
        _progressUpdates.append(progress.fractionCompleted)
        _progressObjects.append(progress)
    }
    
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        _progressUpdates.removeAll()
        _progressObjects.removeAll()
    }
    
    /// Validates that progress values are monotonic (non-decreasing)
    var isProgressMonotonic: Bool {
        let updates = progressUpdates
        for i in 1..<updates.count {
            if updates[i] < updates[i-1] {
                return false
            }
        }
        return true
    }
}