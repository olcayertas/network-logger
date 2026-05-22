import Foundation

public final class BodyStreamTee: InputStream, @unchecked Sendable {
    public typealias Sink = @Sendable (Data) -> Void

    private let upstream: InputStream
    private let limit: Int
    private let sink: Sink
    private var bytesTeed = 0
    private var truncationReported = false

    public init(upstream: InputStream, limit: Int, sink: @escaping Sink) {
        self.upstream = upstream
        self.limit = max(0, limit)
        self.sink = sink
        super.init(data: Data())
    }

    public override var streamStatus: Stream.Status { upstream.streamStatus }
    public override var streamError: Error? { upstream.streamError }
    public override var hasBytesAvailable: Bool { upstream.hasBytesAvailable }

    public override func open() { upstream.open() }
    public override func close() { upstream.close() }

    public override func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
        let bytesRead = upstream.read(buffer, maxLength: len)
        guard bytesRead > 0 else { return bytesRead }

        if limit > 0, bytesTeed < limit {
            let toCopy = min(bytesRead, limit - bytesTeed)
            let chunk = Data(bytes: buffer, count: toCopy)
            sink(chunk)
            bytesTeed += toCopy
            if toCopy < bytesRead, !truncationReported {
                truncationReported = true
            }
        }
        return bytesRead
    }

    public override func getBuffer(
        _ buffer: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>,
        length len: UnsafeMutablePointer<Int>
    ) -> Bool {
        false
    }

    public override func property(forKey key: Stream.PropertyKey) -> Any? {
        upstream.property(forKey: key)
    }

    public override func setProperty(_ property: Any?, forKey key: Stream.PropertyKey) -> Bool {
        upstream.setProperty(property, forKey: key)
    }

    public override func schedule(in aRunLoop: RunLoop, forMode mode: RunLoop.Mode) {
        upstream.schedule(in: aRunLoop, forMode: mode)
    }

    public override func remove(from aRunLoop: RunLoop, forMode mode: RunLoop.Mode) {
        upstream.remove(from: aRunLoop, forMode: mode)
    }
}
