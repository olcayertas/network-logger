# Exporting captures

Four built-in export formats, available from the share menu on both list and detail views.

## Overview

NetworkLogger ships four exporters as `Sendable` values you can also call programmatically:

| Exporter                  | Format                                       | Best for                                       |
|---------------------------|----------------------------------------------|------------------------------------------------|
| ``PlainTextExporter``     | Human-readable text per event                | Bug reports, Slack pastes                      |
| ``CurlExporter``          | Reproducible `curl` commands                 | "Can you reproduce this?" questions            |
| ``PostmanExporter``       | Postman 2.1 JSON collection                  | Importing a session into Postman              |
| ``HARExporter``           | HTTP Archive 1.2 JSON                        | Importing into browser devtools / Charles      |

## From the UI

The list view's "More" toolbar menu and the detail view's share menu both expose:

- Share as text
- Share as cURL
- Share as Postman
- Share as HAR

Each opens the system share sheet, so the output can go to Files, Mail, Messages, or any app that registers for text/JSON content.

## Programmatic export

All four exporters are pure functions:

```swift
let events = await logger.snapshot()

let text     = PlainTextExporter.text(for: events)
let curl     = CurlExporter.string(for: events)
let postman  = PostmanExporter.collection(name: "API debug", from: events)  // Data
let har      = HARExporter.har(from: events)                                 // Data
```

Pair with `try data.write(to: ...)` to dump to disk, or with `ShareLink` for an off-the-shelf share affordance.

## Filtered exports

The export buttons in the list view export the currently visible events (post-filter). That makes it easy to ship "just the failing 5xx requests against /checkout":

1. Type `path:/checkout statusCode:5XX` in the search bar.
2. Tap More → Share as HAR.

The resulting archive contains exactly the filtered subset.
