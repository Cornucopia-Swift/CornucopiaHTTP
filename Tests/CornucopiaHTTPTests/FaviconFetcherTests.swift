//
//  Cornucopia – (C) Dr. Lauer Information Technology
//
import XCTest
@testable import CornucopiaHTTP

final class FaviconFetcherTests: XCTestCase {
    
    private var fetcher: FaviconFetcher!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        fetcher = FaviconFetcher()
    }
    
    override func tearDownWithError() throws {
        fetcher = nil
        try super.tearDownWithError()
    }
    
    func testConstructBaseURLWithDefaultPorts() throws {
        let httpURL = try fetcher.constructBaseURL(host: "example.com", port: 80)
        XCTAssertEqual(httpURL.absoluteString, "http://example.com")
        
        let httpsURL = try fetcher.constructBaseURL(host: "example.com", port: 443)
        XCTAssertEqual(httpsURL.absoluteString, "https://example.com")
    }
    
    func testConstructBaseURLWithCustomPorts() throws {
        let customHTTPURL = try fetcher.constructBaseURL(host: "example.com", port: 8080)
        XCTAssertEqual(customHTTPURL.absoluteString, "http://example.com:8080")
        
        let customHTTPSURL = try fetcher.constructBaseURL(host: "example.com", port: 8443)
        XCTAssertEqual(customHTTPSURL.absoluteString, "https://example.com:8443")
        
        let lowPortURL = try fetcher.constructBaseURL(host: "example.com", port: 8000)
        XCTAssertEqual(lowPortURL.absoluteString, "http://example.com:8000")
    }
    
    func testConstructBaseURLWithHostIncludingScheme() throws {
        let overridden = try fetcher.constructBaseURL(host: "https://example.com", port: 8080)
        XCTAssertEqual(overridden.absoluteString, "https://example.com:8080")
        
        let defaulted = try fetcher.constructBaseURL(host: "https://example.com", port: 80)
        XCTAssertEqual(defaulted.absoluteString, "https://example.com")
    }
    
    func testConstructBaseURLWithHostIncludingPort() throws {
        let url = try fetcher.constructBaseURL(host: "example.com:9090", port: 8080)
        XCTAssertEqual(url.absoluteString, "http://example.com:9090")
    }
    
    func testConstructBaseURLWithIPv6Host() throws {
        let loopback = try fetcher.constructBaseURL(host: "::1", port: 8080)
        XCTAssertEqual(loopback.absoluteString, "http://[::1]:8080")
    }
    
    func testParseFaviconFromHTMLWithIconRel() {
        let html = """
        <html>
        <head>
            <link rel="icon" href="/favicon.png" type="image/png">
        </head>
        <body></body>
        </html>
        """
        
        let baseURL = URL(string: "https://example.com")!
        let faviconInfo = fetcher.parseFaviconFromHTML(html, baseURL: baseURL)
        
        XCTAssertNotNil(faviconInfo)
        XCTAssertEqual(faviconInfo?.url.absoluteString, "https://example.com/favicon.png")
        XCTAssertEqual(faviconInfo?.type, "image/png")
        XCTAssertNil(faviconInfo?.sizes)
    }
    
    func testParseFaviconFromHTMLWithShortcutIcon() {
        let html = """
        <html>
        <head>
            <link rel="shortcut icon" href="/favicon.ico">
        </head>
        <body></body>
        </html>
        """
        
        let baseURL = URL(string: "https://example.com")!
        let faviconInfo = fetcher.parseFaviconFromHTML(html, baseURL: baseURL)
        
        XCTAssertNotNil(faviconInfo)
        XCTAssertEqual(faviconInfo?.url.absoluteString, "https://example.com/favicon.ico")
    }
    
    func testParseFaviconFromHTMLWithAppleTouchIcon() {
        let html = """
        <html>
        <head>
            <link rel="apple-touch-icon" href="/apple-touch-icon.png" sizes="180x180">
        </head>
        <body></body>
        </html>
        """
        
        let baseURL = URL(string: "https://example.com")!
        let faviconInfo = fetcher.parseFaviconFromHTML(html, baseURL: baseURL)
        
        XCTAssertNotNil(faviconInfo)
        XCTAssertEqual(faviconInfo?.url.absoluteString, "https://example.com/apple-touch-icon.png")
        XCTAssertEqual(faviconInfo?.sizes, "180x180")
    }
    
    func testParseFaviconFromHTMLWithAbsoluteURL() {
        let html = """
        <html>
        <head>
            <link rel="icon" href="https://cdn.example.com/favicon.png">
        </head>
        <body></body>
        </html>
        """
        
        let baseURL = URL(string: "https://example.com")!
        let faviconInfo = fetcher.parseFaviconFromHTML(html, baseURL: baseURL)
        
        XCTAssertNotNil(faviconInfo)
        XCTAssertEqual(faviconInfo?.url.absoluteString, "https://cdn.example.com/favicon.png")
    }
    
    func testParseFaviconFromHTMLWithRelativePath() {
        let html = """
        <html>
        <head>
            <link rel="icon" href="images/favicon.png">
        </head>
        <body></body>
        </html>
        """
        
        let baseURL = URL(string: "https://example.com")!
        let faviconInfo = fetcher.parseFaviconFromHTML(html, baseURL: baseURL)
        
        XCTAssertNotNil(faviconInfo)
        XCTAssertEqual(faviconInfo?.url.absoluteString, "https://example.com/images/favicon.png")
    }
    
    func testParseFaviconFromHTMLNoFaviconFound() {
        let html = """
        <html>
        <head>
            <title>Test Page</title>
        </head>
        <body></body>
        </html>
        """
        
        let baseURL = URL(string: "https://example.com")!
        let faviconInfo = fetcher.parseFaviconFromHTML(html, baseURL: baseURL)
        
        XCTAssertNil(faviconInfo)
    }
    
    func testExtractAttribute() {
        let tag = #"<link rel="icon" href="/favicon.png" type="image/png" sizes="32x32">"#
        
        XCTAssertEqual(fetcher.extractAttribute("href", from: tag), "/favicon.png")
        XCTAssertEqual(fetcher.extractAttribute("type", from: tag), "image/png")
        XCTAssertEqual(fetcher.extractAttribute("sizes", from: tag), "32x32")
        XCTAssertNil(fetcher.extractAttribute("nonexistent", from: tag))
    }
    
    func testExtractAttributeCaseInsensitive() {
        let tag = #"<LINK REL="ICON" HREF="/favicon.png" TYPE="image/png">"#
        
        XCTAssertEqual(fetcher.extractAttribute("href", from: tag), "/favicon.png")
        XCTAssertEqual(fetcher.extractAttribute("type", from: tag), "image/png")
    }
}
