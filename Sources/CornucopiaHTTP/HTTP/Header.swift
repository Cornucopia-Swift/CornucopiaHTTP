//
//  Cornucopia – (C) Dr. Lauer Information Technology
//
import CornucopiaCore
import Foundation

extension HTTP {
    
    public enum Header {
        
        case authorization(token: Cornucopia.Core.JWT.Token<Cornucopia.Core.JWT.Payload>)
        case contentEncoding(ContentEncoding)
        case contentLength(Int)
        case contentType(MimeType)
        case range(closed: ClosedRange<Int>)
        case range(partialFrom: PartialRangeFrom<Int>)
        case range(partialThrough: PartialRangeThrough<Int>)
        case userAgent(String)

        public func apply(to urlRequest: inout URLRequest) {
            
            switch self {

                case .userAgent(let value):
                    urlRequest.setValue(value, forHTTPHeaderField: HeaderField.userAgent.rawValue)

                default:
                    fatalError("not yet implemented")
                }
        }
    }
}


extension URLRequest {
    
    public mutating func CC_setHeader(_ header: HTTP.Header) { header.apply(to: &self) }
}
