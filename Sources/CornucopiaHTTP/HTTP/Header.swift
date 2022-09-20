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
        
        case authorization(token: Cornucopia.Core.JWT.Token<Cornucopia.Core.JWT.Payload>)
        case contentEncoding(ContentEncoding)
        case contentLength(Int)
        case contentType(MimeType)
        case rangeClosed(ClosedRange<Int>)
        case rangePartialFrom(PartialRangeFrom<Int>)
        case rangePartialThrough(PartialRangeThrough<Int>)
        case userAgent(String)

        public var field: String {
            switch self {
                case .authorization(_): return HeaderField.authorization.rawValue
                case .contentEncoding(_): return HeaderField.contentEncoding.rawValue
                case .contentLength(_): return HeaderField.contentLength.rawValue
                case .contentType(_): return HeaderField.contentType.rawValue
                case .rangeClosed(_), .rangePartialFrom(_), .rangePartialThrough(_): return HeaderField.range.rawValue
                case .userAgent(_): return HeaderField.userAgent.rawValue
            }
        }

        public var value: String {
            switch self {
                case .userAgent(let value): return value
                default: fatalError("not yet implemented")
            }
        }

        public func apply(to urlRequest: inout URLRequest) { urlRequest.setValue(self.value, forHTTPHeaderField: self.field) }
    }
}


extension URLRequest {
    
    public mutating func CC_setHeader(_ header: HTTP.Header) { header.apply(to: &self) }
}
