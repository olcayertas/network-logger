#if os(iOS)
import SwiftUI
import Perception

/// Lists every persisted session and routes into `RequestListView` for each.
///
/// Used as the root view of `NetworkLoggerView` when file-backed persistence is enabled.
/// The current (live) session is highlighted; past sessions open in read-only mode.
struct SessionListView: View {
    let logger: NetworkLogger
    @State private var sessions: [Session] = []
    @State private var pendingDeletion: Session?

    var body: some View {
        List {
            ForEach(sessions.reversed()) { session in
                NavigationLink(value: SessionRoute(session: session)) {
                    SessionRow(session: session, isCurrent: session.id == logger.currentSessionID)
                }
            }
            .onDelete { offsets in
                let reversed = Array(sessions.reversed())
                for index in offsets {
                    let session = reversed[index]
                    if session.id == logger.currentSessionID { continue }
                    pendingDeletion = session
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Sessions")
        .navigationDestination(for: SessionRoute.self) { route in
            sessionDestination(for: route.session)
        }
        .task { refresh() }
        .refreshable { refresh() }
        .confirmationDialog(
            "Delete this session?",
            isPresented: .constant(pendingDeletion != nil),
            titleVisibility: .visible,
            presenting: pendingDeletion
        ) { session in
            Button("Delete", role: .destructive) {
                logger.persistence?.deleteSession(id: session.id)
                pendingDeletion = nil
                refresh()
            }
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
        } message: { session in
            Text(session.startedAt.formatted(date: .abbreviated, time: .standard))
        }
    }

    @ViewBuilder
    private func sessionDestination(for session: Session) -> some View {
        if session.id == logger.currentSessionID {
            CurrentSessionListView(logger: logger)
        } else if let persistence = logger.persistence {
            PastSessionListView(events: persistence.events(for: session.id), logger: logger)
        }
    }

    private func refresh() {
        sessions = logger.persistence?.sessions() ?? []
    }
}

private struct SessionRoute: Hashable {
    let session: Session
}

private struct SessionRow: View {
    let session: Session
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isCurrent ? "dot.radiowaves.left.and.right" : "clock")
                .foregroundStyle(isCurrent ? Color.accentColor : .secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(isCurrent ? "Current session" : session.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.body)
                Text(session.startedAt.formatted(date: .omitted, time: .standard))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct CurrentSessionListView: View {
    let logger: NetworkLogger
    @State private var model: EventListModel?

    var body: some View {
        Group {
            if let model {
                RequestListView(model: model, logger: logger)
            } else {
                ProgressView()
                    .task {
                        let m = EventListModel(logger: logger)
                        m.start()
                        model = m
                    }
            }
        }
    }
}

private struct PastSessionListView: View {
    let events: [NetworkEvent]
    let logger: NetworkLogger
    @State private var model: EventListModel?

    var body: some View {
        Group {
            if let model {
                RequestListView(model: model, logger: logger)
            } else {
                ProgressView()
                    .task {
                        model = EventListModel(snapshot: events)
                    }
            }
        }
    }
}
#endif
