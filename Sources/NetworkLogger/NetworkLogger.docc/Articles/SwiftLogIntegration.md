# swift-log integration

Pipe your app's swift-log output into NetworkLogger's Console tab.

## Overview

NetworkLogger's UI ships with a **Console** tab alongside **Network**. By default the Console is empty — captures only arrive when you wire up an app-log source.

The `NetworkLoggerLogHandler` product provides a [swift-log](https://github.com/apple/swift-log) `LogHandler` conformance that bridges every `Logger(label:)` call into the logger's `LogEventStore`.

## Install

Add the `NetworkLoggerLogHandler` product to your target alongside `NetworkLogger`. Then, at app startup, bootstrap:

```swift
import Logging
import NetworkLogger
import NetworkLoggerLogHandler

let networkLogger = NetworkLogger(configuration: .init(persistence: .fileBackedDefault))
NetworkLoggerLogHandler.bootstrap(logger: networkLogger)
```

That single call replaces `LoggingSystem`'s factory — every subsequent `Logger(label:)` in your app, in your dependencies, in any library that uses swift-log routes through `NetworkLoggerLogHandler` and lands in the Console tab.

## Per-call usage

After bootstrap, just use swift-log normally:

```swift
let logger = Logger(label: "auth.flow")
logger.info("user signed in", metadata: ["userID": "42"])
logger.warning("token refresh slow", metadata: ["ms": "1450"])
```

The handler stringifies all metadata values (`Logger.MetadataValue` → `String`) and forwards them, along with the source/file/function/line that swift-log captured.

## Console UI

The Console tab shows:

- A coloured **level chip** per row (trace → critical, with `LogEvent.Level.severity` ordering).
- The log **label** (e.g. `"auth.flow"`) for grouping.
- A timestamp.

Tap a row to drill into `LogEventDetailView`: full message, level, label, source/file/function/line, and a metadata key-value table.

Filter from the More menu:

- **Minimum level** — hide trace/debug noise while looking for a warning.
- **Filter by label** — focus on a single source.

## Multiple handlers

Want logs to *also* go to stdout while being captured? swift-log's `MultiplexLogHandler` is the canonical pattern:

```swift
LoggingSystem.bootstrap { label in
    MultiplexLogHandler([
        NetworkLoggerLogHandler(label: label, logger: networkLogger),
        StreamLogHandler.standardOutput(label: label),
    ])
}
```

## Caveats

- `LoggingSystem.bootstrap(_:)` may be called at most once per process. Calling it twice traps.
- `LogEvent`s currently live in memory only — they don't share the file-backed persistence path that ``NetworkEvent``s use. (See <doc:Persistence>.)
