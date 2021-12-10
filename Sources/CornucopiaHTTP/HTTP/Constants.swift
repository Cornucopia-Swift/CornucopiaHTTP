//
//  Cornucopia – (C) Dr. Lauer Information Technology
//
extension HTTP {

    /// Header map typealias
    public typealias Headers = [String: String]
    /// Status and Headers tuple
    public typealias StatusAndHeaders = (status: Status, headers: Headers)

    /// Well-known HTTP methods
    public enum Method: String {
        case CONNECT
        case DELETE
        case GET
        case HEAD
        case OPTIONS
        case PATCH
        case POST
        case PUT
        case TRACE

        /// HTTP Methods used with the WebDAV protocol
        public enum WebDAV: String {
            case COPY
            case LOCK
            case MKCOL
            case PROPFIND
            case PROPPATCH
            case UNLOCK
        }

        /// HTTP Methods used with the RTS protocol
        public enum RTSP: String {
            case ANNOUNCE
            case DESCRIBE
            case GET_PARAMETER
            case PAUSE
            case PLAY
            case RECORD
            case REDIRECT
            case SET_PARAMETER
            case SETUP
            case TEARDOWN
        }
    }

    /// Well-known HTTP header fields
    public enum HeaderField: String {
        case authorization = "Authorization"
        case contentEncoding = "Content-Encoding"
        case contentLength = "Content-Length"
        case contentType = "Content-Type"
        case range = "Range"
        case userAgent = "User-Agent"
    }

    /// Well-known HTTP mime types
    public enum MimeType: String {
        case applicationJSON = "application/json"
        case applicationOctetStream = "application/octet-stream"
        case imageJPEG = "image/jpeg"
        case imageHEIC = "image/heic"
        case textPlain = "text/plain"
        case unknown = "unknown/unknown"
    }
    
    /// Well-known HTTP content encoding types
    public enum ContentEncoding: String {
        case gzip = "gzip"
        case deflate = "deflate"
        case brotli = "br"
    }
} // extension HTTP
