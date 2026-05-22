# NetworkLogger

A modern Swift network-debugging library for iOS — a from-scratch rewrite of [Wormholy](https://github.com/pmusolino/Wormholy) using SwiftUI, Swift 6 strict concurrency, actors, and `URLSession` delegate proxying.

It captures HTTP requests, responses, headers, bodies, and metrics; lets you filter, share, and export as cURL / Postman / HAR / plain text; and lives behind a `NetworkLoggerView` that **you** present wherever you want.

## Why a rewrite

Wormholy is great. NetworkLogger keeps every feature you actually use and drops two architectural pillars that fight modern apps:

| Wormholy | NetworkLogger |
|---|---|
| Walks `UIApplication.shared.connectedScenes → keyWindow → rootViewController` to push its UI | You present `NetworkLoggerView(logger:)` like any SwiftUI view — `.sheet`, `NavigationLink`, fullscreen, tab, inline |
| Shake-to-trigger NSNotification (`wormholy_fire`) is hardwired | No notifications, no shake handler, no global state — wire up whatever trigger you want |
| Method-swizzles `NSURLSessionConfiguration` from an ObjC constructor | Pure-Swift `URLSession` delegate proxy you opt into per session |
| Singleton `Storage.shared`, `@Published` reference types, `DispatchQueue.main.async` updates | `actor EventStore`, `Sendable` value types, Swift 6 strict concurrency |
| `Wormholy.limit` getter that returns `nil` synchronously while doing a `Task { @MainActor in return ... }` | Real async API |

## Installation

Swift Package Manager:

```swift
.package(url: "https://github.com/your-org/network-logger", from: "0.1.0")
```

Add `NetworkLogger` as a dependency to your target.

iOS 16+ (uses the [Perception](https://github.com/pointfreeco/swift-perception) library to back-port `@Observable`). The Swift package targets iOS 16 and macOS 13; UI is iOS-only.

### Excluding from Release builds

Add to your `Release.xcconfig` (or each non-debug target's build settings):

```
EXCLUDED_SOURCE_FILE_NAMES = NetworkLogger*
```

No constructor-time side effects, so the library is inert if you just skip wiring it up.

## Quick start

```swift
import NetworkLogger

// 1. Create an instance — no singleton.
let logger = NetworkLogger(configuration: .init(
    limit: 500,
    ignoredHosts: ["analytics.example.com"]
))

// 2. Attach to a URLSession via the delegate proxy (recommended).
//    Pass your existing delegate as `forwardingTo:` to keep your auth /
//    redirect / progress logic — we forward everything through.
let delegate = await logger.makeSessionDelegate(forwardingTo: myDelegate)
let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)

// 3. Present the inspector wherever you want.
.sheet(isPresented: $showInspector) {
    NetworkLoggerView(logger: logger)
}
```

## Recording modes

Three complementary ways to feed events into a logger. Pick one or combine them.

### 1. URLSession delegate proxy (recommended)

`logger.makeSessionDelegate(forwardingTo:)` returns a `URLSessionDelegate` that records every callback then forwards to your real delegate via Objective-C message forwarding (`responds(to:)` + `forwardingTarget(for:)`). Works with:

- Upload progress (`didSendBodyData:`)
- SSL pinning / server-trust (`didReceive challenge:`)
- HTTP redirects (`willPerformHTTPRedirection:`)
- Multipart bodies (combined with `BodyStreamTee`)
- `URLSessionStreamDelegate` / `URLSessionWebSocketDelegate` — forwarded without any code from us

Limitation: the URLSession **async/await convenience APIs** (`session.data(from:)`, `session.data(for:)` without a per-task delegate) consume the data delegate methods internally, so the session delegate only sees `task` and `auth` events. To capture full request and response bodies via the async API, pass the same delegate as the per-task delegate:

```swift
let delegate = await logger.makeSessionDelegate()
let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)

// Pass the delegate as the per-task delegate too — captures everything:
let (data, response) = try await session.data(from: url, delegate: delegate)
```

Or just call `session.dataTask(with: request).resume()` (delegate-driven, no completion handler) and rely on the session delegate alone.

### 2. Manual recording

For gRPC, WebSocket, or any traffic that doesn't go through `URLSession`:

```swift
let event = NetworkEvent(
    request: .init(
        url: URL(string: "grpc://api.example.com/GetUser")!,
        httpMethod: "POST",
        headers: ["Content-Type": "application/grpc+proto"],
        body: BodyData(data: payload)
    ),
    response: .init(statusCode: 0, body: BodyData(data: reply)),
    metrics: .init(duration: 0.085),
    state: .completed
)
await logger.record(event)
```

### 3. URLProtocol fallback (third-party SDKs)

When you can't reach the URLSession (a closed-source SDK owns it), opt into the global URLProtocol:

```swift
let configuration: URLSessionConfiguration = .default
logger.attach(to: configuration)            // installs LoggingURLProtocol on this config
URLProtocol.registerClass(logger.urlProtocolClass)  // or globally, if you must
```

Limitations baked into Apple's URLProtocol design:

- Cannot forward `didSendBodyData:` for streamed uploads (Wormholy bug #77 — an Apple-level limitation, not ours).
- Background sessions are unsupported.
- The challenge handler always calls its completion handler with `.performDefaultHandling` (fixes Wormholy #157's "API misuse" warning by construction).

## Presenting the UI

`NetworkLoggerView(logger:)` is a plain SwiftUI view that builds its own `NavigationStack`. Drop it wherever:

```swift
// Sheet
.sheet(isPresented: $show) { NetworkLoggerView(logger: logger) }

// Push
NavigationLink("Network Logs") {
    NetworkLoggerView(logger: logger)
}

// Full-screen cover
.fullScreenCover(isPresented: $show) { NetworkLoggerView(logger: logger) }

// Tab in a debug menu
TabView { NetworkLoggerView(logger: logger).tabItem { ... } }
```

The library ships **no** shake-to-present helper, **no** floating overlay button, and **no** NSNotification trigger. Wire up your own trigger — see `Examples/NetworkLoggerDemo` for several patterns.

## Configuration

```swift
NetworkLoggerConfiguration(
    limit: 500,                          // ring buffer size
    ignoredHosts: ["analytics.example.com"],
    defaultFilter: "/api/v2",            // pre-fill the search box
    bodyCaptureLimit: 1_048_576,         // 1 MiB body cap with truncation flag
    headerRedactor: Redaction.makeHeaderRedactor(),  // redacts Authorization, Cookie, ...
    responseTransformer: { data, request in
        // decrypt, decompress, anything you want
        return MyCrypto.decrypt(data)
    }
)
```

Runtime mutation:

```swift
await logger.setLimit(1000)
await logger.setIgnoredHosts(["new.host"])
await logger.setDefaultFilter("/v3/")
await logger.replaceConfiguration(newConfig)
```

## Exporters

```swift
let events = await logger.snapshot()

CurlExporter.string(for: events)                       // multiline cURL commands
PostmanExporter.collection(name: "MyApp", from: events) // Postman 2.1 JSON
PlainTextExporter.text(for: events)                    // human-readable text
HARExporter.har(from: events)                          // HAR 1.2 JSON
```

The built-in UI wires these into `ShareLink` automatically (Save to Files, Mail, Messages, etc.).

## Filters

```swift
let combined = CompositeFilter(
    URLSubstringFilter("/users"),
    MethodFilter("POST"),
    StatusCodeRangeFilter.clientError,
    HostFilter(blocking: ["staging.example.com"])
)
let problems = (await logger.snapshot()).filtered(by: combined)
```

Built-ins: `URLSubstringFilter`, `MethodFilter`, `HostFilter`, `StatusCodeRangeFilter`, `CompositeFilter` (AND), `AnyOfFilter` (OR), `NotFilter`. All `Sendable`. Implement your own by conforming to `EventFilter`.

## Wormholy issue map

| Wormholy issue | NetworkLogger resolution |
|---|---|
| #157 SSL pinning "API MISUSE" | Delegate proxy forwards `didReceive challenge:` to your delegate; URLProtocol mode always calls the completion handler. |
| #147 Empty request body | `BodyStreamTee` clones `httpBodyStream` for the URLProtocol path. The delegate proxy captures from `task.originalRequest.httpBody`, which URLSession preserves. |
| #146 Custom logs (gRPC) | Public `record(_:)` API. |
| #144 Debug-only SPM | `EXCLUDED_SOURCE_FILE_NAMES = NetworkLogger*` per Release config — no library code change needed since there's no constructor side effect. |
| #132 Custom cell content | (Roadmap) cell row override via `RequestListView` initializer. |
| #130 Decrypt response | `Configuration.responseTransformer`. |
| #125 Response mocking (Proxyman-style) | Roadmap (stretch goal). |
| #114 Static linking | ObjC constructor + method swizzling removed entirely. Works by construction. |
| #93 Multipart bodies | Same `BodyStreamTee` path as #147. |
| #77 Alamofire/upload progress | Delegate-proxy mode forwards `didSendBodyData:` to your delegate. URLProtocol mode preserves Apple's limitation but documents it. |

## Concurrency model

- All public mutable state is in an `actor` (`EventStore`, `ConfigurationStore`, per-task `SessionRecorder`).
- `NetworkEvent` and its components are `struct, Sendable` value types.
- `LoggingURLSessionDelegate` is `NSObject, @unchecked Sendable` (URLSession requires NSObject; isolation is enforced by routing all state mutations through the recorder actor).
- UI uses `@Perceptible` (Perception library) `@MainActor` view models subscribed to `logger.eventStream()`.
- No `DispatchQueue.main.async`, no `@Published` on reference types, no implicit globals.

Builds clean under `-strict-concurrency=complete` on Swift 6.

## License

MIT — same as Wormholy.
