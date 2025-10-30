//
//  Cornucopia – (C) Dr. Lauer Information Technology
//
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public final class FaviconFetcher {
    
    public enum Error: Swift.Error {
        case invalidHost(String)
        case noFaviconFound(String)
        case htmlParsingFailed(String)
    }
    
    public struct FaviconInfo {
        public let url: URL
        public let type: String?
        public let sizes: String?
        
        public init(url: URL, type: String? = nil, sizes: String? = nil) {
            self.url = url
            self.type = type
            self.sizes = sizes
        }
    }
    
    private let networking: Networking
    
    public init(networking: Networking = Networking()) {
        self.networking = networking
    }
    
    public func findFaviconURL(for host: String, port: Int = 80) async throws -> FaviconInfo {
        let baseURL = try constructBaseURL(host: host, port: port)
        let rootPageURL = baseURL.appendingPathComponent("/")
        
        let request = URLRequest(url: rootPageURL)
        let htmlData: Data = try await networking.download(urlRequest: request)
        
        guard let htmlString = String(data: htmlData, encoding: .utf8) else {
            throw Error.htmlParsingFailed("Could not decode HTML as UTF-8")
        }
        
        if let faviconInfo = parseFaviconFromHTML(htmlString, baseURL: baseURL) {
            return faviconInfo
        }
        
        let defaultFaviconURL = baseURL.appendingPathComponent("/favicon.ico")
        return FaviconInfo(url: defaultFaviconURL)
    }
    
    internal func constructBaseURL(host: String, port: Int) throws -> URL {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existingURL = URL(string: trimmedHost),
           let scheme = existingURL.scheme,
           let existingHost = existingURL.host {

            var components = URLComponents()
            components.scheme = scheme
            components.host = existingHost

            let defaultPort: Int?
            switch scheme.lowercased() {
                case "http": defaultPort = 80
                case "https": defaultPort = 443
                default: defaultPort = nil
            }

            let effectivePort: Int?
            if let explicitPort = existingURL.port {
                effectivePort = explicitPort
            } else if port != 80 {
                effectivePort = port
            } else {
                effectivePort = defaultPort
            }

            if let effectivePort, effectivePort != defaultPort {
                components.port = effectivePort
            }
            components.path = ""

            guard let normalizedURL = components.url else {
                throw Error.invalidHost("Could not normalize URL for host: \(host)")
            }
            return normalizedURL
        }

        var sanitizedHost = trimmedHost
        var hostProvidedPort: Int? = nil

        if sanitizedHost.contains("://") == false, sanitizedHost.contains(":") {
            let placeholder = "placeholder://\(sanitizedHost)"
            if let derivedComponents = URLComponents(string: placeholder),
               let derivedHost = derivedComponents.host {
                sanitizedHost = derivedHost
                hostProvidedPort = derivedComponents.port
            }
        }

        if sanitizedHost.contains(":"),
           sanitizedHost.contains("[") == false,
           sanitizedHost.contains("]") == false {
            let hexAndColon = CharacterSet(charactersIn: "0123456789abcdefABCDEF:")
            let isLikelyIPv6 = sanitizedHost.unicodeScalars.allSatisfy { hexAndColon.contains($0) }
            if isLikelyIPv6 {
                sanitizedHost = "[\(sanitizedHost)]"
            }
        }

        let effectivePort = hostProvidedPort ?? port

        let scheme: String
        switch effectivePort {
            case 443, 8443, 9443:
                scheme = "https"
            default:
                scheme = "http"
        }

        var components = URLComponents()
        components.scheme = scheme
        components.host = sanitizedHost

        guard components.host != nil else {
            throw Error.invalidHost("Could not construct URL components for host: \(host)")
        }

        if !((effectivePort == 80 && scheme == "http") || (effectivePort == 443 && scheme == "https")) {
            components.port = effectivePort
        }

        guard let url = components.url else {
            throw Error.invalidHost("Could not construct URL for host: \(host):\(port)")
        }

        return url
    }
    
    internal func parseFaviconFromHTML(_ html: String, baseURL: URL) -> FaviconInfo? {
        let linkPatterns = [
            #"<link[^>]*rel\s*=\s*[\"']icon[\"'][^>]*>"#,
            #"<link[^>]*rel\s*=\s*[\"']shortcut\s+icon[\"'][^>]*>"#,
            #"<link[^>]*rel\s*=\s*[\"']apple-touch-icon[\"'][^>]*>"#,
            #"<link[^>]*rel\s*=\s*[\"']apple-touch-icon-precomposed[\"'][^>]*>"#
        ]
        
        for pattern in linkPatterns {
            if let faviconInfo = extractFaviconInfo(from: html, pattern: pattern, baseURL: baseURL) {
                return faviconInfo
            }
        }
        
        return nil
    }
    
    private func extractFaviconInfo(from html: String, pattern: String, baseURL: URL) -> FaviconInfo? {
        let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        
        guard let match = regex?.firstMatch(in: html, options: [], range: range),
              let matchRange = Range(match.range, in: html) else {
            return nil
        }
        
        let linkTag = String(html[matchRange])
        
        guard let href = extractAttribute("href", from: linkTag) else {
            return nil
        }
        
        let faviconURL: URL
        if href.hasPrefix("http://") || href.hasPrefix("https://") {
            guard let url = URL(string: href) else { return nil }
            faviconURL = url
        } else if href.hasPrefix("/") {
            faviconURL = baseURL.appendingPathComponent(href)
        } else {
            faviconURL = baseURL.appendingPathComponent("/").appendingPathComponent(href)
        }
        
        let type = extractAttribute("type", from: linkTag)
        let sizes = extractAttribute("sizes", from: linkTag)
        
        return FaviconInfo(url: faviconURL, type: type, sizes: sizes)
    }
    
    internal func extractAttribute(_ attribute: String, from tag: String) -> String? {
        let pattern = #"\b\#(attribute)\s*=\s*[\"']([^\"']*)[\"']"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        let range = NSRange(tag.startIndex..<tag.endIndex, in: tag)
        
        guard let match = regex?.firstMatch(in: tag, options: [], range: range),
              match.numberOfRanges > 1,
              let valueRange = Range(match.range(at: 1), in: tag) else {
            return nil
        }
        
        return String(tag[valueRange])
    }
}

extension Networking {
    
    func download(urlRequest: URLRequest) async throws -> Data {
        if let mock = Self.mock(for: urlRequest) { return mock.data }
        if let busynessObserver = Self.busynessObserver { busynessObserver.enterBusy() }
        defer { if let busynessObserver = Self.busynessObserver { busynessObserver.leaveBusy() } }
        let (data, _) = try await self.urlSession.data(for: urlRequest, delegate: nil)
        return data
    }
}
