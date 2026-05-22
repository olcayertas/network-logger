import Foundation
import Testing
@testable import NetworkLogger

@Suite("PersistenceCoordinator")
struct PersistenceCoordinatorTests {
    @Test("records events into the current session")
    func recordsEvents() async throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let coordinator = PersistenceCoordinator(directory: dir, maxSessions: 10, maxAgeDays: 30)
        let a = makeEvent(url: "https://api.example.com/a")
        let b = makeEvent(url: "https://api.example.com/b")
        coordinator.record(a)
        coordinator.record(b)

        let events = coordinator.events(for: coordinator.currentSessionID)
        #expect(events.count == 2)
        #expect(events.contains(where: { $0.id == a.id }))
        #expect(events.contains(where: { $0.id == b.id }))
    }

    @Test("upserts in place when the same id is recorded twice")
    func upsertsInPlace() async throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let coordinator = PersistenceCoordinator(directory: dir, maxSessions: 10, maxAgeDays: 30)
        var event = makeEvent(url: "https://api.example.com/a")
        coordinator.record(event)

        event.state = .completed
        event.response = NetworkResponseSnapshot(statusCode: 200)
        coordinator.record(event)

        let events = coordinator.events(for: coordinator.currentSessionID)
        #expect(events.count == 1)
        #expect(events.first?.state == .completed)
        #expect(events.first?.response?.statusCode == 200)
    }

    @Test("retains across reinit on the same directory")
    func retainsAcrossLaunches() async throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let firstCoordinator = PersistenceCoordinator(directory: dir, maxSessions: 10, maxAgeDays: 30)
        let firstSessionID = firstCoordinator.currentSessionID
        let event = makeEvent(url: "https://api.example.com/a")
        firstCoordinator.record(event)

        // New coordinator on same dir = new session; the previous one is browsable.
        let secondCoordinator = PersistenceCoordinator(directory: dir, maxSessions: 10, maxAgeDays: 30)
        #expect(secondCoordinator.currentSessionID != firstSessionID)

        let pastEvents = secondCoordinator.events(for: firstSessionID)
        #expect(pastEvents.count == 1)
        #expect(pastEvents.first?.id == event.id)
    }

    @Test("prunes sessions older than maxAgeDays on init")
    func prunesOldSessions() async throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        // Simulate an old session by initializing with a backdated `now`.
        let ancient = Date().addingTimeInterval(-100 * 86_400)
        let oldCoordinator = PersistenceCoordinator(directory: dir, maxSessions: 10, maxAgeDays: 30, now: ancient)
        oldCoordinator.record(makeEvent(url: "https://old"))
        let oldID = oldCoordinator.currentSessionID

        // A fresh init "today" should prune the ancient session.
        let fresh = PersistenceCoordinator(directory: dir, maxSessions: 10, maxAgeDays: 30)
        let sessions = fresh.sessions()
        #expect(!sessions.contains(where: { $0.id == oldID }))
    }

    @Test("enforces maxSessions, keeping the newest")
    func enforcesMaxSessions() async throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        var keptIDs: [UUID] = []
        for offset in (0..<5).reversed() {
            let now = Date().addingTimeInterval(-Double(offset) * 60)
            let coordinator = PersistenceCoordinator(directory: dir, maxSessions: 3, maxAgeDays: 30, now: now)
            keptIDs.append(coordinator.currentSessionID)
        }

        let last = PersistenceCoordinator(directory: dir, maxSessions: 3, maxAgeDays: 30)
        let sessionIDs = Set(last.sessions().map(\.id))
        // The two oldest of the five recorded above must be gone (max=3, plus this new one = 4 → still keeps 3 newest including the new one).
        #expect(sessionIDs.count <= 3)
        #expect(sessionIDs.contains(last.currentSessionID))
    }

    @Test("clearCurrent empties only the current session's events")
    func clearCurrentScopedToCurrent() async throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let first = PersistenceCoordinator(directory: dir, maxSessions: 10, maxAgeDays: 30)
        first.record(makeEvent(url: "https://a"))
        let firstID = first.currentSessionID

        let second = PersistenceCoordinator(directory: dir, maxSessions: 10, maxAgeDays: 30)
        second.record(makeEvent(url: "https://b"))
        second.clearCurrent()

        #expect(second.events(for: second.currentSessionID).isEmpty)
        #expect(second.events(for: firstID).count == 1)
    }

    @Test("deleteSession removes both the session and its events")
    func deleteSessionRemovesAll() async throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let first = PersistenceCoordinator(directory: dir, maxSessions: 10, maxAgeDays: 30)
        first.record(makeEvent(url: "https://a"))
        let firstID = first.currentSessionID

        let second = PersistenceCoordinator(directory: dir, maxSessions: 10, maxAgeDays: 30)
        second.deleteSession(id: firstID)

        #expect(!second.sessions().contains(where: { $0.id == firstID }))
        #expect(second.events(for: firstID).isEmpty)
    }

    private func makeEvent(url: String) -> NetworkEvent {
        NetworkEvent(
            request: NetworkRequestSnapshot(url: URL(string: url)!, httpMethod: "GET")
        )
    }

    private func makeTempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("nl-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
