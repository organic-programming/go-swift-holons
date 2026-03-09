# Goswift Architecture

## Overview

A Goswift app pairs a Go gRPC daemon with a native SwiftUI frontend.
The daemon handles all business logic; the SwiftUI app is a thin
presentation layer.

## Communication

On macOS, the SwiftUI app stages the bundled daemon as a temporary holon
and calls `connect("gudule-daemon-greeting-goswift")` from
`swift-holons`. The SDK discovers the staged manifest, launches the
daemon, and returns a gRPC channel.

```
┌─────────────────┐  connect(slug) ┌─────────────────┐
│  SwiftUI App    │───────────────▶│  Go Daemon       │
│  (swift-holons) │                │  (gRPC server)   │
└─────────────────┘             └─────────────────┘
```

On iOS, tvOS, watchOS, and visionOS, the app still talks to an already
running daemon, but it does so through the SDK's direct-dial
`connect("<host>:<port>")` path rather than constructing the transport
manually.

## Proto Contract

Both sides share a single `.proto` definition:

- `greeting.v1.GreetingService.ListLanguages` — returns available languages
- `greeting.v1.GreetingService.SayHello` — greets the user in the chosen language

## Key Differences from Godart (Flutter)

| Aspect | Godart | Goswift |
|--------|--------|---------|
| UI framework | Flutter (cross-platform) | SwiftUI (Apple-only) |
| Platforms | macOS, Linux, Windows, iOS, Android | macOS only (for now) |
| gRPC client library | dart-holons SDK | swift-holons SDK |
| Desktop transport | `connect(slug)` → ephemeral localhost TCP | `connect(slug)` |
| Proto codegen | protoc + dart plugin | protoc + swift plugin |
| Build tool | `flutter build` | `swift build` / `xcodebuild` |

## Why `connect(slug)`?

The recipe now relies on the same SDK abstraction as the other migrated
desktop stacks: the frontend names the daemon by slug, stages a
temporary `holon.yaml`, and lets the SDK own startup, connection, and
shutdown.

## Bundle Strategy (Future)

For a proper `.app` bundle, the daemon binary can be embedded in
`Contents/MacOS/` alongside the SwiftUI executable. The `DaemonProcess`
class already searches for it there before falling back to the dev path.
