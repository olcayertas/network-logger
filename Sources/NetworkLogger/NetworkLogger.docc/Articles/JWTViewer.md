# JWT viewer

Detect and decode JSON Web Tokens in captured traffic.

## Overview

NetworkLogger scans `Authorization: Bearer …` headers and JSON body strings for JWT-shaped substrings. Detected tokens render an inline **badge** that opens a jwt.io-style detail sheet — header / payload / signature in three coloured sections, plus standard claims surfaced as labelled rows.

> Important: **No signature verification is performed.** The viewer is for debugging only. The "validity" banner reflects `exp`/`nbf` time-window checks alone.

## How detection works

``JWTDetector`` looks for the pattern `eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]*` — the canonical base64url-of-`{"` prefix, three dot-separated segments. Every regex hit is then run through ``JWT/init(_:)``; substrings that fail to decode are skipped. That filters out random `eyJ…` matches that aren't actually JWTs.

`JWTDetector.jwtFromAuthorizationHeader(_:)` strips a leading `Bearer ` (case-insensitive) and parses the rest.

## What's surfaced

The detail view shows:

- **Validity banner** — Valid / Expired / Not yet valid, based on `exp` and `nbf`.
- **Standard claims** — `alg`, `typ`, `kid` (from the header), and `iss`, `sub`, `aud`, `exp`, `iat`, `nbf`, `jti` (from the payload).
- **Header section** (red) — pretty-printed JSON.
- **Payload section** (purple) — pretty-printed JSON.
- **Signature section** (cyan) — raw base64url string + an explicit "not verified" note.
- **Raw section** — the full `header.payload.signature` for copy-paste.

A toolbar button copies the raw token to the clipboard.

## Programmatic use

You can decode JWTs outside the UI too:

```swift
import NetworkLogger

guard let jwt = JWT(rawTokenString) else { return }
print(jwt.claims.sub ?? "no sub")
print(jwt.headerPrettyJSON)

switch jwt.validity() {
case .valid: print("ok")
case .expired(let since): print("expired since \(since)")
case .notYetValid(let until): print("not yet valid; nbf=\(until)")
}
```
