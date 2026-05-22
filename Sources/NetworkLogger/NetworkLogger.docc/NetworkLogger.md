# ``NetworkLogger``

A modern Swift network-debugging library for iOS — a from-scratch rewrite of [Wormholy](https://github.com/pmusolino/Wormholy) using SwiftUI, Swift 6 strict concurrency, actors, and `URLSession` delegate proxying.

## Overview

`NetworkLogger` captures HTTP requests, responses, headers, bodies, and metrics from `URLSession` traffic and presents them through a SwiftUI inspector you embed wherever you want — a sheet, a tab, a navigation push. It deliberately avoids the architectural pitfalls of older debug libraries:

- **No method-swizzling**, no global notification triggers, no walking the connected-scenes graph.
- **Pure-Swift `URLSession` delegate proxy** that opts you in per session.
- **Actor-backed event store** with `Sendable` value types and Swift 6 strict concurrency.
- **Opt-in products à la carte** — bare core, plus optional `NetworkLoggerMediaViewers`, `NetworkLoggerLogHandler`, and `NetworkLoggerDependencies`.

```swift
import NetworkLogger

let logger = NetworkLogger(configuration: .init(
    limit: 500,
    ignoredHosts: ["analytics.example.com"]
))

// 1. Build a pre-wired session.
let session = logger.makeLoggingURLSession()
let (data, response) = try await session.data(for: request)

// 2. Show the inspector anywhere.
.sheet(isPresented: $showInspector) {
    NetworkLoggerView(logger: logger)
}
```

## Topics

### Getting started

- <doc:GettingStarted>
- <doc:NetworkCapture>

### Filtering and searching

- <doc:Filtering>
- ``SearchToken``
- ``StatusCodeRange``
- ``DateRangeFilter``

### Persisting and exporting

- <doc:Persistence>
- <doc:Exporting>
- ``Session``

### Integrations

- <doc:SwiftLogIntegration>
- <doc:JWTViewer>
- ``BodyViewer``

### Core types

- ``NetworkLogger/NetworkLogger``
- ``NetworkLoggerConfiguration``
- ``NetworkEvent``
- ``EventStore``
- ``LogEvent``
- ``LogEventStore``

### Capture entry points

- ``LoggingURLSession``
- ``LoggingURLSessionDelegate``
- ``LoggingURLProtocol``

### Stores

- ``PersistenceCoordinator``
- ``RecentSearchesStore``
- ``PinnedEventsStore``

### Next steps

- <doc:NextSteps>
