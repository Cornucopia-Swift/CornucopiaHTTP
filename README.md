# CornucopiaHTTP – Modern Swift HTTP Networking

CornucopiaHTTP is a Swift Package Manager library that wraps `URLSession` in a modern async/await API, providing typed requests, automatic JSON handling, optional compression, progress callbacks, and background transfers.

## Installation

Add CornucopiaHTTP to your package manifest:

```swift
dependencies: [
    .package(url: "https://github.com/Cornucopia-Swift/CornucopiaHTTP", branch: "master")
]
```

Import the module in the targets that need networking:

```swift
.target(
    name: "MyApp",
    dependencies: [
        .product(name: "CornucopiaHTTP", package: "CornucopiaHTTP")
    ]
)
```

## Quick Tour

### Fetch typed data with the static API

```swift
import CornucopiaHTTP

struct User: Codable {
    let id: Int
    let name: String
}

var request = URLRequest(url: URL(string: "https://api.example.com/users/1")!)
request.setValue("application/json", forHTTPHeaderField: "Accept")

let user: User = try await HTTP.GET(from: request)
```

### Create resources with an instance

```swift
let networking = Networking()

struct CreateUser: Encodable { var name: String }
struct CreatedUser: Decodable { var id: Int; var name: String }

let url = URL(string: "https://api.example.com/users")!
let create = CreateUser(name: "Ada")

let created: CreatedUser = try await networking.POST(item: create, to: URLRequest(url: url))
print("New user id", created.id)
```

### Download files and observe progress

```swift
let downloadURL = FileManager.default.temporaryDirectory.appendingPathComponent("archive.zip")
let request = URLRequest(url: URL(string: "https://downloads.example.com/archive.zip")!)

let headers = try await networking.GET(from: request, to: downloadURL, progressObserver: { progress in
    print("Progress", progress.fractionCompleted)
})

print("Saved to", downloadURL.path)
print("Content-Length:", headers["Content-Length"] ?? "unknown")
```

### Background transfers on Apple platforms

```swift
#if canImport(ObjectiveC)
let backgroundNetworking = OOPNetworking.shared
let task = try backgroundNetworking.GET(from: URLRequest(url: url), to: downloadURL)
print("Task identifier:", task.taskIdentifier)
#endif
```

## Configuration Highlights

- **Reuse an existing `URLSession`:** set `Networking.customURLSession` before creating instances.
- **Observe UI state:** provide a `CornucopiaCore.BusynessObserver` via `Networking.busynessObserver` to toggle loading indicators.
- **Enable upload compression:** allow gzip on selected endpoints.

```swift
try Networking.enableCompressedUploads(
    for: Regex("https://api.example.com/v1/.*"),
    key: "api-v1"
)
```

Disable it again with `Networking.disableCompressedUploads(for: "api-v1")`.

## Error Handling

`Networking.Error` captures common failure cases:

- `.unsuitableRequest` for malformed requests
- `.unsuccessful(HTTP.Status)` for non-success status codes
- `.unsuccessfulWithDetails` when the server returns a JSON error payload
- `.decodingError` when decoding the response fails

Use Swift’s `do/catch` to differentiate between them:

```swift
do {
    let profile: User = try await HTTP.GET(from: request)
} catch Networking.Error.unsuccessful(let status) {
    logger.error("Server returned \(status)")
} catch Networking.Error.decodingError(let error) {
    logger.error("JSON decoding failed: \(error)")
} catch {
    logger.error("Unexpected networking error: \(error)")
}
```

## Mocking and Local Testing

`Networking.registerMockData(_:httpStatus:contentType:for:)` lets you stub responses without hitting the network.

```swift
let url = URL(string: "https://api.example.com/users/preview")!
let payload = try JSONEncoder().encode(User(id: 42, name: "Preview"))

Networking.registerMockData(
    payload,
    httpStatus: .OK,
    contentType: .applicationJSON,
    for: url
)

let preview: User = try await HTTP.GET(from: URLRequest(url: url)) // served from the mock
```

Mocks are stored in memory. Register the data you expect before invoking your API under test.

## Utilities

- **FaviconFetcher** – locate a site’s favicon (or fall back to `/favicon.ico`) using the existing networking stack.
- **Progress helpers** – `Networking.ProgressObserver` closures work for both real and mocked downloads.

## Running the Test Suite

Integration tests can auto-start a JSON server at `http://localhost:3000` when `json-server` is installed at `/opt/homebrew/bin/json-server`. If it's not installed or you prefer to run it yourself, start it in a separate terminal:

```bash
json-server json-server/db.json
```

Then run the Swift tests:

```bash
swift test
swift test --filter HTTPTests    # run a subset
```

## Platform Support

- iOS 16.0+
- macOS 13.0+
- tvOS 16.0+
- watchOS 9.0+
- Linux with Swift 5.10+

## Dependencies

- [CornucopiaCore](https://github.com/Cornucopia-Swift/CornucopiaCore) – JSON codecs, logging, utility types
- [SWCompression](https://github.com/tsolomko/SWCompression) – gzip compression
- [FoundationBandAid](https://github.com/mickeyl/FoundationBandAid) – Linux compatibility layer

## License

CornucopiaHTTP is released under the MIT license. Contributions and bug reports are welcome.
