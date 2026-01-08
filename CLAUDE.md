# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Build and Test
```bash
swift build                    # Build the package
swift test                     # Run all tests
swift test --filter testGET    # Run specific test
```

### Running Tests with Mock Server
Integration tests auto-start a JSON server on localhost:3000 when `json-server` is available at `/opt/homebrew/bin/json-server`. If it's not installed or you want to run it yourself, start it manually:
```bash
json-server json-server/db.json
```

## Architecture Overview

CornucopiaHTTP is a Swift Package Manager library providing modern async/await HTTP networking abstractions for Swift 5.5+.

### Core Components

**HTTP.swift** - Static convenience methods for HTTP operations (GET, POST, PUT, DELETE, etc.)
- Provides simple static interface: `HTTP.GET<T>(from: URLRequest)`
- All methods delegate to `Networking` class instances

**Networking.swift** - Core networking implementation
- Instance-based HTTP client with full async/await support
- Handles JSON encoding/decoding, compression, mocking, and error handling
- Supports progress observation for file downloads
- Integrates with `CornucopiaCore.BusynessObserver` for UI state management

**OOPNetworking.swift** - Background/out-of-process networking (Apple platforms only)
- Uses `URLSessionConfiguration.background` for downloads that survive app suspension
- Supports client certificate authentication via PKCS12
- Manages background task lifecycle and file operations

### Key Patterns

- **Dual APIs**: Both static convenience methods (`HTTP.*`) and instance methods (`Networking().*`)
- **Generic Type Safety**: Extensive use of `Encodable`/`Decodable` constraints for type-safe JSON operations
- **Automatic Compression**: Gzip compression applied automatically to uploads when beneficial
- **Mock Support**: Built-in mocking system for testing (see `Networking+Mocking.swift`)
- **Progress Observation**: File download progress via closure-based observers

### Dependencies

- **CornucopiaCore**: Provides JSON encoder/decoder and logging infrastructure
- **SWCompression**: Handles gzip compression/decompression
- **FoundationBandAid**: Linux compatibility layer (conditional import)

### Platform Support

- iOS 16+, macOS 13+, tvOS 16+, watchOS 9+
- Linux support (with FoundationBandAid)
- Swift 5.10+ required
