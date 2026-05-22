import Foundation
import Testing
@testable import NetworkLogger

@Suite("PinnedEventsStore")
struct PinnedEventsStoreTests {
    @Test("pin and unpin")
    func pinAndUnpin() throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = PinnedEventsStore(directory: dir)
        let id = UUID()
        #expect(!store.isPinned(id))

        store.pin(id)
        #expect(store.isPinned(id))

        store.unpin(id)
        #expect(!store.isPinned(id))
    }

    @Test("togglePin flips state")
    func togglePinFlips() throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = PinnedEventsStore(directory: dir)
        let id = UUID()
        store.togglePin(id)
        #expect(store.isPinned(id))
        store.togglePin(id)
        #expect(!store.isPinned(id))
    }

    @Test("pinning is idempotent")
    func pinIsIdempotent() throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = PinnedEventsStore(directory: dir)
        let id = UUID()
        store.pin(id)
        store.pin(id)
        #expect(store.snapshot().count == 1)
    }

    @Test("clear empties the set")
    func clearEmpties() throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = PinnedEventsStore(directory: dir)
        store.pin(UUID())
        store.pin(UUID())
        store.clear()
        #expect(store.snapshot().isEmpty)
    }

    @Test("persists across reinit")
    func persistsAcrossLaunches() throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let id = UUID()
        let first = PinnedEventsStore(directory: dir)
        first.pin(id)

        let second = PinnedEventsStore(directory: dir)
        #expect(second.isPinned(id))
    }

    private func makeTempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("nl-pins-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
