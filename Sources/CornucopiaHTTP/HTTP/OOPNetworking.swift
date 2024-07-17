//
//  Cornucopia – (C) Dr. Lauer Information Technology
//
#if canImport(ObjectiveC)
import CornucopiaCore
import Foundation
import SWCompression

private var logger = Cornucopia.Core.Logger()

/// Support for out-of-process networking on [Apple platforms](https://developer.apple.com/documentation/foundation/url_loading_system/downloading_files_in_the_background/).
public final class OOPNetworking: NSObject {

    /// A blueprint for customizing the internal `URLSessionConfiguration`.
    /// NOTE: This needs to be set before calling the `shared` method for the first time.
    public static var customConfigurationBlueprint: URLSessionConfiguration? = nil
    /// The shared instance.
    public static let shared: OOPNetworking = .init()
    /// Currently outstanding background tasks.
    public var tasks: Set<URLSessionTask> = []
    /// Client certificates.
    public var certificates: [String: Cornucopia.Core.PKCS12] = [:] // key is host, value is pkcs12

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: Self.identifier)
        config.isDiscretionary = false
        //configuration.sessionSendsLaunchEvents = false
        if let configurationBlueprint = Self.customConfigurationBlueprint {
#if !os(macOS)
            config.multipathServiceType = configurationBlueprint.multipathServiceType
#endif
            config.httpAdditionalHeaders = configurationBlueprint.httpAdditionalHeaders
            //FIXME: Anything more here?
        }
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        let semaphore = DispatchSemaphore(value: 0)
        session.getAllTasks { tasks in
            defer { semaphore.signal() }
            self.tasks = Set(tasks)
        }
        semaphore.wait()
        return session
    }()

    private override init() {
        super.init()
        _ = self.session
    }

    private static let identifier: String = "dev.cornucopia.http.BackgroundTransfers"
}

//MARK: Public API (Security)
public extension OOPNetworking {
    func addCertificate(from source: Cornucopia.Core.PKCS12, for host: String) {
        self.certificates[host] = source
    }
}

//MARK: Public API (HTTP)
public extension OOPNetworking {

    /// Issues a GET request, writing the output to a file.
    /// Returns the (original) URL for looking up the status in the `tasks` property.
    @discardableResult
    func GET(from urlRequest: URLRequest, to destinationURL: URL) throws -> URLSessionDownloadTask {
        guard let url = urlRequest.url else { throw Networking.Error.unsuitableRequest("Missing URL") }
        guard !self.tasks.contains(where: { $0.originalRequest?.url == url } ) else { throw Networking.Error.unsuitableRequest("Already downloading from URL \(url)") }
        var urlRequest = urlRequest
        urlRequest.mainDocumentURL = destinationURL // save the destinationURL to spare another lookup
        let task = self.session.downloadTask(with: urlRequest)
        self.tasks.insert(task)
        task.resume()
        logger.debug("Launched GET for \(url) => \(destinationURL.absoluteString). Outstanding tasks: \(self.tasks.count)")
        return task
    }

    @discardableResult
    func POST<UP: Encodable>(item: UP, via urlRequest: URLRequest) throws -> URLSessionUploadTask {
        var urlRequest = urlRequest
        urlRequest.httpMethod = HTTP.Method.POST.rawValue
        guard let url = urlRequest.url else { throw Networking.Error.unsuitableRequest("Missing URL") }
        let data = try Networking.prepareUpload(item: item, in: &urlRequest)
        let fileUrl = FileManager.CC_urlInTempDirectory(suffix: "\(UUID())")
        try data.write(to: fileUrl)
        let task = self.session.uploadTask(with: urlRequest, fromFile: fileUrl)
        self.tasks.insert(task)
        task.resume()
        // By the time, `resume()` returns, the file has been copied into the URLSession framework's private temporary store. We can now safely delete it.
        // NOTE: This doesn't seem to be properly documented.
        try? FileManager.default.removeItem(at: fileUrl)
        logger.debug("Launched POST of a '\(type(of: item))' to \(url). Outstanding tasks: \(self.tasks.count)")
        return task
    }
}

//MARK: - URLSessionDelegate, URLSessionDownloadDelegate
extension OOPNetworking: URLSessionDelegate, URLSessionDownloadDelegate {

    public func urlSession(_: URLSession, downloadTask: URLSessionDownloadTask, didWriteData _: Int64, totalBytesWritten _: Int64, totalBytesExpectedToWrite _: Int64) {
        logger.debug("Progress \(downloadTask.progress.fractionCompleted) for \(downloadTask)")
    }

    public func urlSession(_: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let destinationURL = downloadTask.originalRequest?.mainDocumentURL else {
            logger.error("Can't load destinationURL from task. I have no idea where to copy the file to.")
            return
        }
        do {
            try? FileManager.default.removeItem(at: destinationURL) // ignore, if it's not existing
            try FileManager.default.copyItem(at: location, to: destinationURL)
            logger.info("Download finished and moved to \(destinationURL.absoluteString)")
        } catch {
            logger.error("Can't move \(location) to \(destinationURL): \(error)")
        }
    }

    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let authenticationMethod = challenge.protectionSpace.authenticationMethod
        logger.trace("Did receive URL authentication challenge w/ method '\(authenticationMethod). Host \(challenge.protectionSpace.host):\(challenge.protectionSpace.port)', Realm \(challenge.protectionSpace.realm ?? "N/A")")
        guard authenticationMethod == NSURLAuthenticationMethodClientCertificate else {
            logger.trace("Auth method is not NSURLAuthenticationMethodClientCertificate, using default handling")
            completionHandler(.performDefaultHandling, nil)
            return
        }
        guard let certificateForHost = self.certificates[challenge.protectionSpace.host] else {
            logger.trace("No certificate for host \(challenge.protectionSpace.host), using default handling")
            completionHandler(.performDefaultHandling, nil)
            return
        }
        // Apple seems to recommend that we do not pass the certificate chain into
        // the URLCredential used to respond to the challenge.
        let credential = URLCredential(identity: certificateForHost.identity, certificates: nil, persistence: .none)
        challenge.sender?.use(credential, for: challenge)
        logger.trace("Supplying provided identity")
        completionHandler(.useCredential, credential)
    }

    public func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            logger.error("Task \(task) failed w/ error: \(error)")
        } else {
            logger.info("Task \(task) finished")
        }
        self.tasks.remove(task)
    }
}

#endif
