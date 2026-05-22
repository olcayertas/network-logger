# Getting started

Install NetworkLogger, capture your first request, and open the inspector.

## Install via Swift Package Manager

Add NetworkLogger to your project's `Package.swift`:

```swift
.package(url: "https://github.com/olcayertas/network-logger", from: "0.2.0")
```

Then add one or more of the products to your target:

| Product                       | Brings in                                     | When to use                                                    |
|-------------------------------|-----------------------------------------------|----------------------------------------------------------------|
| `NetworkLogger`               | swift-perception, swift-sharing               | Always — core capture + minimal UI (text + JSON body viewer).  |
| `NetworkLoggerDependencies`   | the above + swift-dependencies                | For `@Dependency(\.networkLogger)` integration.                |
| `NetworkLoggerMediaViewers`   | the above + WebKit + PDFKit                   | Inline image / HTML / PDF body previews.                       |
| `NetworkLoggerLogHandler`     | the above + swift-log                         | Route swift-log into the Console tab.                          |

Bare-minimum consumers stay on `NetworkLogger` and never link WebKit, PDFKit, or swift-log.

## Three-line quickstart

```swift
import NetworkLogger

let logger = NetworkLogger()                   // 1. own one instance
let session = logger.makeLoggingURLSession()    // 2. capture URLSession traffic
NetworkLoggerView(logger: logger)               // 3. open the inspector anywhere
```

## Excluding from Release builds

The library has no constructor-time side effects, so simply not wiring it up keeps it inert. To strip the source code from Release builds too, add to your `Release.xcconfig` (or each non-debug target's build settings):

```
EXCLUDED_SOURCE_FILE_NAMES = NetworkLogger*
```

## Next

- Learn the three capture modes: <doc:NetworkCapture>
- Add structured search and date filters: <doc:Filtering>
- Persist captures across launches: <doc:Persistence>
