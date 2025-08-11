# CornucopiaHTTP – Modern Swift HTTP Networking

🐚 The "horn of plenty" – a symbol of abundance.

A Swift Package Manager library providing modern async/await HTTP networking abstractions for Swift 5.5+.

## Features

- **Modern async/await API** - Clean, readable asynchronous networking
- **Dual API Design** - Static convenience methods (`HTTP.*`) and instance-based methods (`Networking().*`)
- **Generic Type Safety** - Extensive use of `Encodable`/`Decodable` for type-safe JSON operations
- **Automatic Compression** - Gzip compression applied automatically to uploads when beneficial
- **File Downloads** - Support for file downloads with progress observation
- **Background Downloads** - Out-of-process networking for downloads that survive app suspension (Apple platforms only)
- **Built-in Mocking** - Comprehensive mocking system for testing
- **Cross-Platform** - iOS, macOS, tvOS, watchOS, and Linux support

## Quick Start

### Installation

Add CornucopiaHTTP to your Swift package dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/Cornucopia-Swift/CornucopiaHTTP", branch: "master")
]
```

### Basic Usage

#### Static API (Simple and Direct)

```swift
import CornucopiaHTTP

// GET request with automatic JSON decoding
struct User: Codable {
    let id: Int
    let name: String
}

let user: User = try await HTTP.GET(from: URLRequest(url: URL(string: "https://api.example.com/users/1")!))

// POST request with JSON encoding/decoding
let newUser = User(id: 0, name: "Alice")
let createdUser: User = try await HTTP.POST(item: newUser, to: URLRequest(url: URL(string: "https://api.example.com/users")!))

// Simple POST without expecting response body
try await HTTP.POST(item: newUser, via: URLRequest(url: URL(string: "https://api.example.com/users")!))

// File download
try await HTTP.GET(from: URLRequest(url: URL(string: "https://example.com/file.zip")!), to: downloadURL)

// Other HTTP methods
try await HTTP.PUT(item: updatedUser, to: request)
try await HTTP.PATCH(item: userUpdate, to: request)
try await HTTP.DELETE(via: request)
let headers = try await HTTP.HEAD(at: request)
```

#### Instance API (More Control)

```swift
let networking = Networking()

// Same operations with instance methods
let user: User = try await networking.GET(from: request)
let createdUser: User = try await networking.POST(item: newUser, to: request)

// File download with progress observation
try await networking.GET(from: request, to: downloadURL) { progress in
    print("Download progress: \(progress.fractionCompleted)")
}
```

#### Background Downloads (Apple Platforms Only)

```swift
let backgroundNetworking = OOPNetworking()
try await backgroundNetworking.GET(from: request, to: downloadURL)
```

## Advanced Features

### Compression Configuration

```swift
// Configure compression for specific URL patterns
Networking.configureCompression(for: "https://api.example.com/.*", enabled: true)
```

### Custom URLSession

```swift
Networking.customURLSession = myCustomSession
```

### Progress Observation

```swift
try await HTTP.GET(from: request, to: destinationURL) { progress in
    DispatchQueue.main.async {
        progressBar.progress = Float(progress.fractionCompleted)
    }
}
```

### Error Handling

```swift
do {
    let user: User = try await HTTP.GET(from: request)
} catch Networking.Error.unsuccessful(let status) {
    print("HTTP error: \(status)")
} catch Networking.Error.decodingError(let error) {
    print("JSON decoding failed: \(error)")
} catch {
    print("Network error: \(error)")
}
```

### Mocking for Tests

```swift
// Register mock data for testing
Networking.registerMockData(for: "https://api.example.com/users/1") {
    User(id: 1, name: "Test User")
}

// Your tests will now use the mock data instead of real network calls
let user: User = try await HTTP.GET(from: request) // Returns mock data
```

## Platform Requirements

- **iOS** 16.0+
- **macOS** 13.0+
- **tvOS** 16.0+
- **watchOS** 9.0+
- **Linux** (with Swift 5.10+)

## Dependencies

- [CornucopiaCore](https://github.com/Cornucopia-Swift/CornucopiaCore) - JSON encoder/decoder and logging infrastructure
- [SWCompression](https://github.com/tsolomko/SWCompression) - Gzip compression/decompression
- [FoundationBandAid](https://github.com/mickeyl/FoundationBandAid) - Linux compatibility layer (Linux only)

## Testing

The library includes comprehensive unit and integration tests. Tests automatically manage the required JSON server for integration testing:

```bash
# Run all tests
swift test

# Run specific test suites
swift test --filter HTTPTests
swift test --filter NetworkingTests
```

No manual setup required - the test suite automatically starts and stops the JSON server as needed.

## Architecture

### Core Components

- **HTTP.swift** - Static convenience methods for all HTTP operations
- **Networking.swift** - Instance-based HTTP client with full async/await support
- **OOPNetworking.swift** - Background/out-of-process networking (Apple platforms only)

### Key Design Patterns

- **Dual APIs**: Both static convenience methods and instance methods for different use cases
- **Generic Type Safety**: Extensive use of `Encodable`/`Decodable` constraints
- **Automatic Compression**: Gzip compression applied when beneficial
- **Progress Observation**: Closure-based progress callbacks for file operations
- **Comprehensive Error Handling**: Detailed error types for different failure scenarios

## Contributing

This library is licensed under the terms of the MIT License. Contributions are always welcome!