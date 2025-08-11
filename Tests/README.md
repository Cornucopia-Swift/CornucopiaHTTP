# CornucopiaHTTP Test Suite

This directory contains a comprehensive test suite for CornucopiaHTTP, covering all major functionality of the HTTP networking library.

## Test Structure

### Unit Tests (Mocked)
- **HTTPTests.swift** - Tests for all HTTP static convenience methods (GET, POST, PUT, PATCH, DELETE, HEAD)
- **NetworkingTests.swift** - Tests for Networking class instance methods and custom configurations  
- **ErrorHandlingTests.swift** - Comprehensive error handling and edge case testing
- **CompressionTests.swift** - Tests for upload compression functionality and configuration
- **MockingTests.swift** - Tests for the built-in mocking system
- **ProgressObservationTests.swift** - Tests for download progress observation

### Integration Tests (Requires External Services)
- **CornucopiaHTTPTests.swift** - Integration tests that require a running JSON server

### Test Helpers
- **TestHelpers.swift** - Utility functions, test data structures, and helper classes

## Running Tests

### Unit Tests
Unit tests use the built-in mocking system and can be run independently:

```bash
swift test --filter HTTPTests
swift test --filter NetworkingTests  
swift test --filter ErrorHandlingTests
swift test --filter CompressionTests
swift test --filter MockingTests
swift test --filter ProgressObservationTests
```

### Integration Tests
Integration tests require a JSON server running on localhost:3000:

```bash
# Start the JSON server (in project root)
json-server json-server/db.json

# Run integration tests
swift test --filter CornucopiaHTTPIntegrationTests
```

### All Tests
```bash
# Run all tests (requires JSON server)
swift test
```

## Test Coverage

### HTTP Methods Covered
- ✅ GET (with and without type parameters, file downloads)
- ✅ POST (create operations, status-only responses, binary data)
- ✅ PUT (update operations)
- ✅ PATCH (partial updates, different input/output types)
- ✅ DELETE (resource deletion)
- ✅ HEAD (header-only requests)

### Features Covered
- ✅ JSON encoding/decoding with various structures
- ✅ Binary data handling
- ✅ File download operations
- ✅ Progress observation for downloads
- ✅ Request/response compression
- ✅ Error handling (HTTP errors, JSON decoding errors, network errors)
- ✅ Mocking system for testing
- ✅ Custom URLSession configuration
- ✅ Thread safety
- ✅ Edge cases and error conditions

### Error Scenarios Covered
- ✅ HTTP 4xx/5xx errors (with and without JSON error details)
- ✅ JSON decoding failures
- ✅ Unexpected MIME types
- ✅ Network connectivity issues
- ✅ File system errors
- ✅ Invalid request configurations

### Compression Testing
- ✅ Compression configuration (enable/disable by URL pattern)
- ✅ Large payload compression
- ✅ Small payload handling
- ✅ Multiple compression rules
- ✅ Regex pattern matching

## Test Architecture

### Mocking Strategy
Tests use the built-in `Networking.registerMockData()` system to avoid external dependencies in unit tests. This provides:
- Deterministic test results
- Fast execution
- Offline testing capability
- Full control over response scenarios

### Progress Testing
Progress observation tests verify:
- Progress callback execution
- Progress value validity (0.0 to 1.0 range)
- Monotonic progress updates
- Thread safety of callbacks
- Error handling during progress

### Integration Testing
Integration tests provide end-to-end validation using a real JSON server, ensuring:
- Full network stack functionality
- Real compression behavior
- Actual file operations
- Complete request/response cycles

## Adding New Tests

### For New Features
1. Add unit tests using mocks in the appropriate test file
2. Add integration tests if external network calls are needed
3. Use `TestHelpers` utilities for common operations
4. Follow existing naming conventions (`test[Method]_[Scenario]`)

### Test Helpers Available
- `TestHelpers.uniqueTestURL()` - Generate unique test URLs
- `TestHelpers.temporaryFileURL()` - Create temp file URLs  
- `TestHelpers.generateTestData()` - Create test data of specified size
- `TestHelpers.registerJSONMock()` - Easily register JSON mocks
- `ProgressTracker` - Helper for testing progress callbacks

## Notes

- Unit tests are designed to run quickly and reliably without external dependencies
- Integration tests provide comprehensive validation but require network access
- The test suite covers both the static convenience API (`HTTP.*`) and instance-based API (`Networking().*`)
- All tests are designed to be run in parallel safely
- Temporary files are automatically cleaned up after tests