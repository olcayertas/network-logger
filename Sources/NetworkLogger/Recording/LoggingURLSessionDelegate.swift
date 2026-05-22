import Foundation

public final class LoggingURLSessionDelegate: NSObject, @unchecked Sendable {
    private let logger: NetworkLogger
    private let recorder: SessionRecorder
    private let strongForwardee: (any URLSessionDelegate)?
    private weak var weakForwardee: AnyObject?

    public init(
        logger: NetworkLogger,
        forwardingTo delegate: (any URLSessionDelegate)? = nil,
        retainForwardee: Bool = true,
        bodyCaptureLimit: Int = 1_048_576
    ) {
        self.logger = logger
        self.recorder = SessionRecorder(logger: logger, bodyCaptureLimit: bodyCaptureLimit)
        if retainForwardee {
            self.strongForwardee = delegate
            self.weakForwardee = nil
        } else {
            self.strongForwardee = nil
            self.weakForwardee = delegate as AnyObject?
        }
    }

    private var forwardee: AnyObject? {
        if let strongForwardee { return strongForwardee as AnyObject }
        return weakForwardee
    }

    private func respondingForwardee(for selector: Selector) -> AnyObject? {
        guard let target = forwardee else { return nil }
        return target.responds(to: selector) ? target : nil
    }

    public override func responds(to aSelector: Selector!) -> Bool {
        if super.responds(to: aSelector) { return true }
        return forwardee?.responds(to: aSelector) ?? false
    }

    public override func forwardingTarget(for aSelector: Selector!) -> Any? {
        if let target = forwardee, target.responds(to: aSelector) {
            return target
        }
        return nil
    }
}

extension LoggingURLSessionDelegate: URLSessionDelegate {
    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        let sel = #selector(URLSessionDelegate.urlSession(_:didBecomeInvalidWithError:))
        if let target = respondingForwardee(for: sel) as? URLSessionDelegate {
            target.urlSession?(session, didBecomeInvalidWithError: error)
        }
    }

    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @Sendable @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let sel = #selector(URLSessionDelegate.urlSession(_:didReceive:completionHandler:))
        if let target = respondingForwardee(for: sel) as? URLSessionDelegate {
            target.urlSession?(session, didReceive: challenge, completionHandler: completionHandler)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

extension LoggingURLSessionDelegate: URLSessionTaskDelegate {
    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @Sendable @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let sel = #selector(URLSessionTaskDelegate.urlSession(_:task:didReceive:completionHandler:))
        if let target = respondingForwardee(for: sel) as? URLSessionTaskDelegate {
            target.urlSession?(session, task: task, didReceive: challenge, completionHandler: completionHandler)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }

    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @Sendable @escaping (URLRequest?) -> Void
    ) {
        let sel = #selector(URLSessionTaskDelegate.urlSession(_:task:willPerformHTTPRedirection:newRequest:completionHandler:))
        if let target = respondingForwardee(for: sel) as? URLSessionTaskDelegate {
            target.urlSession?(session, task: task, willPerformHTTPRedirection: response, newRequest: request, completionHandler: completionHandler)
        } else {
            completionHandler(request)
        }
    }

    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        needNewBodyStream completionHandler: @Sendable @escaping (InputStream?) -> Void
    ) {
        let sel = #selector(URLSessionTaskDelegate.urlSession(_:task:needNewBodyStream:))
        if let target = respondingForwardee(for: sel) as? URLSessionTaskDelegate {
            target.urlSession?(session, task: task, needNewBodyStream: completionHandler)
        } else {
            completionHandler(nil)
        }
    }

    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        let taskID = task.taskIdentifier
        Task {
            await recorder.sentBodyData(
                taskID: taskID,
                totalBytesSent: totalBytesSent,
                totalExpectedToSend: totalBytesExpectedToSend
            )
        }

        let sel = #selector(URLSessionTaskDelegate.urlSession(_:task:didSendBodyData:totalBytesSent:totalBytesExpectedToSend:))
        if let target = respondingForwardee(for: sel) as? URLSessionTaskDelegate {
            target.urlSession?(
                session,
                task: task,
                didSendBodyData: bytesSent,
                totalBytesSent: totalBytesSent,
                totalBytesExpectedToSend: totalBytesExpectedToSend
            )
        }
    }

    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didFinishCollecting metrics: URLSessionTaskMetrics
    ) {
        let taskID = task.taskIdentifier
        Task {
            await recorder.collectedMetrics(taskID: taskID, metrics: metrics)
        }

        let sel = #selector(URLSessionTaskDelegate.urlSession(_:task:didFinishCollecting:))
        if let target = respondingForwardee(for: sel) as? URLSessionTaskDelegate {
            target.urlSession?(session, task: task, didFinishCollecting: metrics)
        }
    }

    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        let taskID = task.taskIdentifier
        let originalSnapshot = task.originalRequest.map {
            RequestSnapshotBuilder.make(from: $0, session: session)
        }
        // Only treat as an update if the URL actually changed (real redirect).
        // Otherwise `currentRequest` is just the same request with the body
        // moved to httpBodyStream, which would clobber the body we captured.
        let redirectSnapshot: NetworkRequestSnapshot?
        if let current = task.currentRequest,
           let original = task.originalRequest,
           current.url != original.url {
            redirectSnapshot = RequestSnapshotBuilder.make(from: current, session: session)
        } else {
            redirectSnapshot = nil
        }
        Task {
            if let originalSnapshot {
                await recorder.ensureStarted(taskID: taskID, request: originalSnapshot)
            }
            if let redirectSnapshot {
                await recorder.updateRequest(taskID: taskID, request: redirectSnapshot)
            }
            await recorder.finished(taskID: taskID, error: error)
        }

        let sel = #selector(URLSessionTaskDelegate.urlSession(_:task:didCompleteWithError:))
        if let target = respondingForwardee(for: sel) as? URLSessionTaskDelegate {
            target.urlSession?(session, task: task, didCompleteWithError: error)
        }
    }
}

extension LoggingURLSessionDelegate: URLSessionDataDelegate {
    public func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @Sendable @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        if let originalRequest = dataTask.originalRequest {
            let snapshot = RequestSnapshotBuilder.make(from: originalRequest, session: session)
            let taskID = dataTask.taskIdentifier
            Task {
                await recorder.start(taskID: taskID, request: snapshot)
                if let httpResponse = response as? HTTPURLResponse {
                    await recorder.receivedResponse(taskID: taskID, response: httpResponse)
                }
            }
        }

        let sel = #selector(URLSessionDataDelegate.urlSession(_:dataTask:didReceive:completionHandler:))
        if let target = respondingForwardee(for: sel) as? URLSessionDataDelegate {
            target.urlSession?(session, dataTask: dataTask, didReceive: response, completionHandler: completionHandler)
        } else {
            completionHandler(.allow)
        }
    }

    public func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive data: Data
    ) {
        let taskID = dataTask.taskIdentifier
        Task {
            await recorder.receivedData(taskID: taskID, data: data)
        }

        let sel = NSSelectorFromString("URLSession:dataTask:didReceiveData:")
        if let target = respondingForwardee(for: sel) as? URLSessionDataDelegate {
            target.urlSession?(session, dataTask: dataTask, didReceive: data)
        }
    }

    public func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        willCacheResponse proposedResponse: CachedURLResponse,
        completionHandler: @Sendable @escaping (CachedURLResponse?) -> Void
    ) {
        let sel = #selector(URLSessionDataDelegate.urlSession(_:dataTask:willCacheResponse:completionHandler:))
        if let target = respondingForwardee(for: sel) as? URLSessionDataDelegate {
            target.urlSession?(session, dataTask: dataTask, willCacheResponse: proposedResponse, completionHandler: completionHandler)
        } else {
            completionHandler(proposedResponse)
        }
    }
}
