import Foundation
import Testing
@testable import NetworkLogger

@Suite("RecentSearchesStore")
struct RecentSearchesStoreTests {
    @Test("records a search to the head of the list")
    func recordsToHead() throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = RecentSearchesStore(directory: dir)
        store.record("foo")
        store.record("bar")
        #expect(store.snapshot() == ["bar", "foo"])
    }

    @Test("trims whitespace and rejects empty")
    func trimsAndRejectsEmpty() throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = RecentSearchesStore(directory: dir)
        store.record("   ")
        store.record("  api  ")
        #expect(store.snapshot() == ["api"])
    }

    @Test("re-recording an existing term moves it to head")
    func reRecordMovesToHead() throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = RecentSearchesStore(directory: dir)
        store.record("a")
        store.record("b")
        store.record("c")
        store.record("a")
        #expect(store.snapshot() == ["a", "c", "b"])
    }

    @Test("case-insensitive dedupe")
    func caseInsensitiveDedupe() throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = RecentSearchesStore(directory: dir)
        store.record("API")
        store.record("api")
        #expect(store.snapshot() == ["api"])
    }

    @Test("enforces the limit")
    func enforcesLimit() throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = RecentSearchesStore(directory: dir, limit: 3)
        store.record("a")
        store.record("b")
        store.record("c")
        store.record("d")
        #expect(store.snapshot() == ["d", "c", "b"])
    }

    @Test("remove drops the given term")
    func removeDropsTerm() throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = RecentSearchesStore(directory: dir)
        store.record("a")
        store.record("b")
        store.remove("a")
        #expect(store.snapshot() == ["b"])
    }

    @Test("persists across reinit")
    func persistsAcrossLaunches() throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let first = RecentSearchesStore(directory: dir)
        first.record("hello")

        let second = RecentSearchesStore(directory: dir)
        #expect(second.snapshot() == ["hello"])
    }

    private func makeTempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("nl-recents-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
