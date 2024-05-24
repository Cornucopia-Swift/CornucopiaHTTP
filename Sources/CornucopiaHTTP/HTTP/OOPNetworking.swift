//
//  Cornucopia – (C) Dr. Lauer Information Technology
//
#if canImport(ObjectiveC)
import CornucopiaCore
import Foundation
import SWCompression

private var logger = Cornucopia.Core.Logger()

public final class OOPNetworking: NSObject {

    public var tasks: [URL: URLSessionTask] = [:]
    public static let instance: OOPNetworking = .init()

    private static let identifier: String = "dev.cornucopia.http.BackgroundTransfers"
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: Self.identifier)
        config.isDiscretionary = false
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        //session.configuration.sessionSendsLaunchEvents = false
        let semaphore = DispatchSemaphore(value: 0)
        session.getAllTasks { tasks in

            defer { semaphore.signal() }
            self.tasks = [:]
            for task in tasks {
                guard let url = task.originalRequest?.url else {
                    logger.debug("Ignoring task without original request URL: \(task)")
                    continue
                }
                self.tasks[url] = task
            }
        }
        semaphore.wait()
        return session
    }()

    private lazy var networking: Networking = {

        Networking.customURLSession = self.session
        return Networking()
    }()

    private override init() {
        super.init()
        _ = self.session
    }
}

//MARK: Public API
public extension OOPNetworking {

    /// Issues a GET request, writing the output to a file.
    /// Returns the (original) URL for looking up the status in the `tasks` property.
    func GET(from urlRequest: URLRequest, to destinationURL: URL) -> URL {
        guard let url = urlRequest.url else { precondition(false, "urlRequest has no URL") }
        var urlRequest = urlRequest
        urlRequest.mainDocumentURL = destinationURL // save the destinationURL to spare another lookup
        let task = self.session.downloadTask(with: urlRequest)
        self.tasks[url] = task
        task.resume()
        logger.debug("Launched OOP-GET for \(url) => \(destinationURL.absoluteString)")
        return url
    }
}

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

    public func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            logger.error("Task \(task) error: \(error)")
        } else {
            logger.info("Task \(task) finished")
        }
    }
}

#endif
