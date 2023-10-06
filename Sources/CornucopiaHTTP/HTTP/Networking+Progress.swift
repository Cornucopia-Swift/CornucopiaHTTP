//
//  Cornucopia – (C) Dr. Lauer Information Technology
//
import CornucopiaCore
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(FoundationBandAid)
import FoundationBandAid
#endif
import SWCompression

private let logger = Cornucopia.Core.Logger()

extension Networking {

    class DownloadDelegate: NSObject, URLSessionDataDelegate, URLSessionDownloadDelegate {

        typealias Continuation = CheckedContinuation<(HTTP.Headers), Swift.Error>

        private let progressObserver: ProgressObserver
        private let continuation: Continuation
        private let destination: URL
        private var response: HTTPURLResponse! = nil
        private var headers: [String: String] = [:]
        private var status: HTTP.Status = .Unknown
        private var progress: Progress = .init()

        init(continuation: Continuation, destination: URL, progressObserver: @escaping ProgressObserver) {
            self.continuation = continuation
            self.destination = destination
            self.progressObserver = progressObserver
        }

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void) {
            //defer { dataTask.delegate = nil }

            guard let httpResponse = response as? HTTPURLResponse else {
                completionHandler(.cancel)
                let error = Error.unexpectedResponse("\(type(of: response)) != HTTPURLResponse")
                self.continuation.resume(throwing: error)
                return
            }
            self.response = httpResponse
            self.headers = httpResponse.allHeaderFields as? [String: String] ?? [:]

            let status = HTTP.Status(rawValue: httpResponse.statusCode) ?? .Unknown
            guard status.responseType == .Success else {
                completionHandler(.cancel)
                let error = Error.unsuccessful(status)
                self.continuation.resume(throwing: error)
                return
            }
            self.status = status
            completionHandler(.becomeDownload)
        }

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome downloadTask: URLSessionDownloadTask) {
            downloadTask.delegate = self
        }

        func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
            self.progress.totalUnitCount = totalBytesExpectedToWrite
            self.progress.completedUnitCount = totalBytesWritten
            self.progressObserver(self.progress)
        }

        private func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            defer { task.delegate = nil }
            if let error {
                self.continuation.resume(throwing: error)
                return
            }
        }

        func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
            defer { downloadTask.delegate = nil }
            try? FileManager.default.removeItem(at: destination) // might fail, if not existing, we don't care
            do {
                try FileManager.default.moveItem(at: location, to: destination)
                self.continuation.resume(returning: self.headers)
            } catch {
                self.continuation.resume(throwing: error)
            }
        }

        deinit {
            //print("\(Date()): deinit")
        }
    }

    /// Load a resource asynchronously, but offer a way to observe progress.
    public func load(urlRequest: URLRequest, to destinationURL: URL, progressObserver: @escaping ProgressObserver) async throws -> HTTP.Headers {
        if let busynessObserver = Self.busynessObserver { busynessObserver.enterBusy() }
        defer { if let busynessObserver = Self.busynessObserver { busynessObserver.leaveBusy() } }
        let headers = try await withCheckedThrowingContinuation { c in
            
            let task = self.urlSession.dataTask(with: urlRequest)
            task.delegate = DownloadDelegate(continuation: c, destination: destinationURL, progressObserver: progressObserver)
            task.resume()
        }
        return headers
    }
}
