import Foundation
import os

/// Accumulates per-task URLSession data-delegate callbacks and resumes a
/// `CheckedContinuation` when the task completes.
///
/// ## Why `OSAllocatedUnfairLock`, not an actor
///
/// The three `URLSessionDataDelegate` / `URLSessionTaskDelegate` methods that
/// mutate state (`didReceive response:`, `didReceive data:`,
/// `didCompleteWithError:`) are **synchronous, ObjC-style callbacks** that
/// URLSession delivers on its own internal serial delegate queue. They must
/// return before the next callback can be delivered, and `completionHandler`
/// must be invoked inside the method. None of that is compatible with
/// `await`, so an actor cannot host these methods.
///
/// `Synchronization.Mutex` would be the cross-platform successor but is iOS 18+,
/// and this package targets iOS 16 / macOS 13. `OSAllocatedUnfairLock` wraps
/// its protected state (compiler-enforced `withLock` access), is itself
/// `@Sendable`, and is the recommended modern lock for Apple platforms when a
/// per-platform primitive is acceptable.
///
/// `@unchecked Sendable` is deliberately absent: the lock's own conformance is
/// sufficient. The only other stored property (`bodyCaptureLimit`) is an
/// immutable `let`.
final class TaskResultSink: NSObject {

    // MARK: Internal types

    private struct Pending {
        var accumulatedData: Data
        var response: URLResponse?
        let continuation: CheckedContinuation<(Data, URLResponse), Error>
    }

    // MARK: State

    private let bodyCaptureLimit: Int
    private let state: OSAllocatedUnfairLock<[Int: Pending]>

    // MARK: Init

    init(bodyCaptureLimit: Int = 1_048_576) {
        self.bodyCaptureLimit = bodyCaptureLimit
        self.state = OSAllocatedUnfairLock(initialState: [:])
    }

    // MARK: Public interface

    /// Registers a continuation for `task`, resumes `task`, and suspends the
    /// caller until `didCompleteWithError` fires.
    ///
    /// Cancellation: `withTaskCancellationHandler` calls `task.cancel()` if the
    /// enclosing Swift Task is cancelled. URLSession then delivers
    /// `didCompleteWithError` with a cancellation error, resuming the
    /// continuation. The `Pending` entry is inserted before `task.resume()` so
    /// the delegate callback always finds it, even if URLSession dispatches
    /// faster than the continuation suspends.
    func run(_ request: URLRequest, on session: URLSession) async throws -> (Data, URLResponse) {
        let task = session.dataTask(with: request)
        let taskID = task.taskIdentifier
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(Data, URLResponse), Error>) in
                state.withLock {
                    $0[taskID] = Pending(
                        accumulatedData: Data(),
                        response: nil,
                        continuation: continuation
                    )
                }
                task.resume()
            }
        } onCancel: {
            task.cancel()
        }
    }
}

extension TaskResultSink: URLSessionDataDelegate {

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        state.withLock {
            $0[dataTask.taskIdentifier]?.response = response
        }
        completionHandler(.allow)
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive data: Data
    ) {
        state.withLock { pending in
            guard var entry = pending[dataTask.taskIdentifier] else { return }
            let remaining = bodyCaptureLimit - entry.accumulatedData.count
            guard remaining > 0 else { return }
            entry.accumulatedData.append(remaining < data.count ? data.prefix(remaining) : data)
            pending[dataTask.taskIdentifier] = entry
        }
    }
}

extension TaskResultSink: URLSessionTaskDelegate {

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        // Atomic remove so a stray second callback can't double-resume.
        let pending: Pending? = state.withLock { $0.removeValue(forKey: task.taskIdentifier) }
        guard let pending else { return }

        if let error {
            pending.continuation.resume(throwing: error)
        } else if let response = pending.response {
            pending.continuation.resume(returning: (pending.accumulatedData, response))
        } else {
            pending.continuation.resume(throwing: URLError(.badServerResponse))
        }
    }
}
