# Goswift Architecture

## Overview

A Goswift app pairs a Go gRPC daemon with a native SwiftUI frontend.
The daemon handles all business logic; the SwiftUI app is a thin
presentation layer.

## Communication

On macOS, the daemon is launched as a child process via `Foundation.Process`.
The SwiftUI app connects to it over TCP on `localhost:9091`.

```
┌─────────────────┐     TCP     ┌─────────────────┐
│  SwiftUI App    │────────────▶│  Go Daemon       │
│  (gRPC client)  │             │  (gRPC server)   │
└─────────────────┘             └─────────────────┘
```

## Proto Contract

Both sides share a single `.proto` definition:

- `greeting.v1.GreetingService.ListLanguages` — returns available languages
- `greeting.v1.GreetingService.SayHello` — greets the user in the chosen language

## Key Differences from Godart (Flutter)

| Aspect | Godart | Goswift |
|--------|--------|---------|
| UI framework | Flutter (cross-platform) | SwiftUI (Apple-only) |
| Platforms | macOS, Linux, Windows, iOS, Android | macOS only (for now) |
| gRPC client library | dart-holons SDK | grpc-swift |
| Desktop transport | `connect(slug)` → ephemeral localhost TCP | tcp:// localhost |
| Proto codegen | protoc + dart plugin | protoc + swift plugin |
| Build tool | `flutter build` | `swift build` / `xcodebuild` |

## Why TCP Instead of Stdio?

grpc-swift v2 expects an NIO-based transport. The simplest production-ready
option is TCP on localhost. This also makes debugging easier (you can `grpcurl`
the daemon directly).

## Bundle Strategy (Future)

For a proper `.app` bundle, the daemon binary can be embedded in
`Contents/MacOS/` alongside the SwiftUI executable. The `DaemonProcess`
class already searches for it there before falling back to the dev path.
