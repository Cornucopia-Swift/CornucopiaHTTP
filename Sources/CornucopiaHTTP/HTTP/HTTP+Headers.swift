//
//  Cornucopia – (C) Dr. Lauer Information Technology
//
import CornucopiaCore
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

extension HTTP {
    
    @frozen public enum Header {

        case acceptLanguage(String)
        case authorization(token: Cornucopia.Core.JWT.Token<Cornucopia.Core.JWT.Payload>)
        case contentDisposition([String])
        case contentEncoding(ContentEncoding)
        case contentLength(Int)
        case contentType(MimeType)
        case rangeClosed(ClosedRange<Int>)
        case rangePartialFrom(PartialRangeFrom<Int>)
        case rangePartialThrough(PartialRangeThrough<Int>)
        case userAgent(String)

        public var field: String {
            switch self {
                case .acceptLanguage(_):        HeaderField.acceptLanguage.rawValue
                case .authorization(_):         HeaderField.authorization.rawValue
                case .contentDisposition(_):    HeaderField.contentDisposition.rawValue
                case .contentEncoding(_):       HeaderField.contentEncoding.rawValue
                case .contentLength(_):         HeaderField.contentLength.rawValue
                case .contentType(_):           HeaderField.contentType.rawValue
                case .rangeClosed(_),
                     .rangePartialFrom(_),
                     .rangePartialThrough(_):   HeaderField.range.rawValue
                case .userAgent(_):             HeaderField.userAgent.rawValue
            }
        }

        public var value: String {
            switch self {
                case .userAgent(let value): value
                default: fatalError("not yet implemented")
            }
        }

        public func apply(to urlRequest: inout URLRequest) { urlRequest.setValue(self.value, forHTTPHeaderField: self.field) }
    }
}


extension URLRequest {
    
    public mutating func CC_setHeader(_ header: HTTP.Header) { header.apply(to: &self) }
}
