import Foundation
import Testing
@testable import NetworkLogger

@Suite("BodyStreamTee")
struct BodyStreamTeeTests {

    @Test("forwards bytes to the consumer and the sink")
    func forwardsAndTees() throws {
        let payload = Data("multipart-body".utf8)
        let upstream = InputStream(data: payload)
        let sink = ByteSink()
        let tee = BodyStreamTee(upstream: upstream, limit: 1024, sink: sink.append)

        tee.open()
        let read = readAll(stream: tee)
        tee.close()

        #expect(read == payload)
        #expect(sink.collected == payload)
    }

    @Test("respects byte cap with truncation")
    func respectsCap() {
        let payload = Data(repeating: 0xAB, count: 4096)
        let upstream = InputStream(data: payload)
        let sink = ByteSink()
        let tee = BodyStreamTee(upstream: upstream, limit: 1024, sink: sink.append)

        tee.open()
        let read = readAll(stream: tee)
        tee.close()

        #expect(read == payload)
        #expect(sink.collected.count == 1024)
    }

    @Test("zero limit does not call sink")
    func zeroLimitNoSink() {
        let payload = Data("ignored".utf8)
        let upstream = InputStream(data: payload)
        let sink = ByteSink()
        let tee = BodyStreamTee(upstream: upstream, limit: 0, sink: sink.append)

        tee.open()
        _ = readAll(stream: tee)
        tee.close()

        #expect(sink.collected.isEmpty)
    }

    @Test("preserves byte order")
    func preservesByteOrder() {
        let payload = Data((0..<256).map { UInt8($0) })
        let upstream = InputStream(data: payload)
        let sink = ByteSink()
        let tee = BodyStreamTee(upstream: upstream, limit: payload.count, sink: sink.append)

        tee.open()
        _ = readAll(stream: tee)
        tee.close()

        #expect(sink.collected == payload)
    }

    private func readAll(stream: InputStream, bufferSize: Int = 128) -> Data {
        var output = Data()
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read > 0 {
                output.append(buffer, count: read)
            } else {
                break
            }
        }
        return output
    }
}

final class ByteSink: @unchecked Sendable {
    private(set) var collected = Data()
    private let lock = NSLock()

    func append(_ chunk: Data) {
        lock.lock()
        collected.append(chunk)
        lock.unlock()
    }
}
