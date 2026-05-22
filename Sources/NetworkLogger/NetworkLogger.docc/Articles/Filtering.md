# Filtering and searching

Compose filters in code or type structured tokens into the search bar.

## Overview

The list view drives a `CompositeFilter` chain. Three kinds of filters feed into it:

- Programmatic filters (composable values that conform to ``EventFilter``).
- Structured search tokens typed into the search bar.
- A date-range filter applied via the toolbar's clock button.

## Programmatic filters

Every primitive filter is a `Sendable` value type conforming to ``EventFilter``:

| Filter                          | Predicate                                                        |
|---------------------------------|------------------------------------------------------------------|
| ``URLSubstringFilter``          | substring match on the full URL                                  |
| ``URLPathFilter``               | substring match scoped to `url.path`                             |
| ``HostFilter``                  | allow- or block-list of host suffixes                            |
| ``MethodFilter``                | exact HTTP method                                                |
| ``StatusCodeRangeFilter``       | response code within a `ClosedRange<Int>`                        |
| ``DateRangeFilter``             | `event.startDate` within a `ClosedRange<Date>`                   |

Compose with `CompositeFilter` (AND), `AnyOfFilter` (OR), and `NotFilter` (negation).

## Structured search tokens

Type any of these prefixes into the search bar:

```
host:api.example.com
method:POST
path:/users
statusCode:200      statusCode:2XX      statusCode:200..<300
status:404          code:5XX
```

The shape mirrors [Pulse's](https://github.com/kean/Pulse) `ConsoleSearchToken`. Anything that doesn't parse as a token stays as free text and matches the URL substring. Active tokens render as chips below the search bar; tapping a chip's `×` removes that token from the input.

## Date range filter

Tap the clock toolbar button to open ``DateRangeFilter/Preset``-driven presets:

- Last 5 minutes
- Last hour
- Today
- Yesterday
- Last 7 days
- Custom (two `DatePicker`s)

A chip appears at the top of the list while a range is active. Tap its `×` to clear.

## Recent searches

The search bar's suggestions panel surfaces the user's most recent committed searches (capped at 10, persisted across launches via swift-sharing's `.fileStorage`). Tapping a recent fills the search field — including any structured tokens — and the chip view re-parses them automatically.

## Pinned requests

Swipe a row from the leading edge to pin it. Pins survive launches and sessions, indexed by `NetworkEvent.id`. The pin-icon toolbar toggle filters the visible list to pinned rows only.

## Default filter

`NetworkLoggerConfiguration.defaultFilter` pre-fills the search bar on first appearance. Useful for shaping the inspector to a specific feature area:

```swift
NetworkLogger(configuration: .init(defaultFilter: "host:api.example.com path:/checkout"))
```
