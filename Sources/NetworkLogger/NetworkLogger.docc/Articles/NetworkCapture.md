# Capturing network traffic

Three ways to feed URLSession events into your logger.

## Overview

NetworkLogger never registers itself globally and never swizzles `URLSession`'s init. You opt in per session, and you choose between three capture mechanisms based on how your app constructs its sessions.

## 1. Delegate proxy (recommended)

For sessions you build yourself, the delegate proxy is the most thorough capture mode — it sees auth challenges, redirects, multipart body bytes, and metrics:

```swift
let logger = NetworkLogger()
let session = logger.makeLoggingURLSession()
let (data, response) = try await session.data(for: request)
```

If your app already has its own delegate, forward through ours:

```swift
let delegate = await logger.makeSessionDelegate(forwardingTo: myDelegate)
let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
```

`LoggingURLSessionDelegate` uses Objective-C message forwarding to delegate any callback we don't care about back to your delegate — including ones you implement that we don't.

## 2. URLProtocol (fallback for opaque sessions)

When a third-party SDK builds its own `URLSession` you can't reach, register the protocol:

```swift
let config = URLSessionConfiguration.default
logger.attach(to: config)
let session = URLSession(configuration: config)
```

Or register globally (use sparingly — this affects every URL load in the process):

```swift
URLProtocol.registerClass(logger.urlProtocolClass)
```

The URLProtocol path can't observe upload progress (Apple doesn't expose `didSendBodyData` to URLProtocol), so prefer the delegate proxy when you control the session.

## 3. Manual record (gRPC, WebSocket, custom transports)

For traffic that doesn't go through URLSession at all, build a `NetworkEvent` and hand it to the logger:

```swift
let event = NetworkEvent(
    request: .init(url: URL(string: "grpc://api/UserService/Get")!, httpMethod: "POST"),
    response: .init(statusCode: 0, headers: ["grpc-status": "0"]),
    metrics: .init(duration: 0.085),
    state: .completed
)
await logger.record(event)
```

## Redaction and transformation

Sensitive headers are redacted by default (`Authorization`, `Cookie`, `Set-Cookie`, `Proxy-Authorization`). Override per-instance:

```swift
NetworkLogger(configuration: .init(
    headerRedactor: { headers in
        // your custom redaction
    },
    responseTransformer: { data, request in
        // decrypt / decompress before storage
    }
))
```

## Body capture limit

`bodyCaptureLimit` (default 1 MiB) caps how many bytes of each body we hold in memory. Bodies above the limit are truncated and the original size is recorded so the UI can show "1.2 MB (truncated to 1 MB)".
