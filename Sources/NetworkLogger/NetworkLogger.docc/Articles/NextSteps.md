# Next steps

Related libraries and ideas for further reading.

## Inspirations and alternatives

- [**kean/Pulse**](https://github.com/kean/Pulse) — broader-scope native logger with a desktop companion, Core Data persistence, and multi-platform UI variants.
- [**pmusolino/Wormholy**](https://github.com/pmusolino/Wormholy) — the original UIKit-era debugging library NetworkLogger was rewritten from.
- [**Proxyman**](https://proxyman.io) — full proxy + mock platform. NetworkLogger is not a proxy; if you need to intercept traffic outside your own app, look at Proxyman.

## Companion libraries

- [**Point-Free's swift-sharing**](https://github.com/pointfreeco/swift-sharing) — the persistence backbone behind ``PersistenceCoordinator``, ``RecentSearchesStore``, and ``PinnedEventsStore``.
- [**Point-Free's swift-dependencies**](https://github.com/pointfreeco/swift-dependencies) — pair with `NetworkLoggerDependencies` for `@Dependency(\.networkLogger)`.
- [**apple/swift-log**](https://github.com/apple/swift-log) — pair with `NetworkLoggerLogHandler` for unified app+network logs.

## Possible future work

- Pulse-style timing waterfall for `URLSessionTaskTransactionMetrics`.
- Per-redirect "transaction" view when a request hops multiple times.
- Response mocking driven from inside the inspector.
- Persisting `LogEvent`s alongside `NetworkEvent`s (currently in-memory only).
- A macOS / visionOS UI surface — at present the UI is iOS-only.

If any of these would help your work, file an issue or PR.
