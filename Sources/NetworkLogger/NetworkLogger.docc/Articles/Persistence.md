# Persistence and sessions

File-backed storage via Point-Free's swift-sharing — no Core Data, no SQLite.

## Overview

NetworkLogger ships with two persistence modes:

- **In-memory (default).** Events live only in the actor-backed ``EventStore`` for the lifetime of the process.
- **File-backed.** A ``PersistenceCoordinator`` mirrors the in-memory store into a single JSON file via [`swift-sharing`](https://github.com/pointfreeco/swift-sharing)'s `@Shared(.fileStorage(_:))`. Survives launches and crashes.

## Enabling persistence

```swift
let logger = NetworkLogger(configuration: .init(
    persistence: .fileBackedDefault
))
```

The default writes under `Application Support/NetworkLogger/`. To customise the location:

```swift
.persistence(.fileBacked(
    directory: URL.applicationSupportDirectory.appendingPathComponent("MyApp"),
    maxSessions: 5,
    maxAgeDays: 14
))
```

## Sessions

Each `NetworkLogger` initialisation creates a new ``Session`` (UUID + start date). When persistence is enabled, the inspector roots on `SessionListView` instead of jumping straight into the current request list — so you can browse "this run" alongside "previous run" without losing the current capture stream.

## Retention

The coordinator applies retention on every init:

1. Drop sessions whose `startedAt` is older than `maxAgeDays` (default 14).
2. If more than `maxSessions` remain (default 5), drop the oldest.

Past sessions can also be deleted manually from `SessionListView` via swipe-to-delete. The current session can't be deleted that way — clear it with the "Clear" toolbar action instead.

## What's persisted

The on-disk envelope holds:

- The list of ``Session``s, oldest first.
- Per-session arrays of ``NetworkEvent``s.

Recent searches (``RecentSearchesStore``) and pinned event ids (``PinnedEventsStore``) live in their own files, sharing the same directory. They persist regardless of which persistence mode you pick — UI preferences shouldn't depend on whether you also persist events.

## What's not persisted

- swift-log entries (``LogEvent``s captured via the `NetworkLoggerLogHandler` product) currently live in memory only.
- Header redactors and response transformers — they're closures, set at init time.
- Stream subscribers — they reattach on the next launch's events.
