//
//  Cornucopia – (C) Dr. Lauer Information Technology
//
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

extension Networking {

    private static var compressedUploadWhitelist: [String: Regex<Substring>] = [:]

    internal static func shouldCompressUpload(urlRequest: URLRequest) -> Bool {
        guard let stringUrl = urlRequest.url?.absoluteString else { return false }
        return Self.compressedUploadWhitelist.contains { _, whitelistEntry in
            stringUrl.wholeMatch(of: whitelistEntry) != nil
        }
    }

    /// Register a whitelist entry
    public static func enableCompressedUploads(for regex: Regex<Substring>, key: String) {
        Self.compressedUploadWhitelist[key] = regex
    }
    
    /// Unregister a whitelist entry
    public static func disableCompressedUploads(for key: String) {
        Self.compressedUploadWhitelist[key] = nil
    }
}
