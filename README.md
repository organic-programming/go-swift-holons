# GOSWIFT (`go-swift-holons`)

Goswift is the recipe stack for composite apps with a Go backend and a
SwiftUI frontend.

This repository has two faces:

1. It is a toolkit for building your own composite apps: scripts,
   architecture notes, and a working example.
2. It is a living showcase: `examples/greeting/` ships the full
   `Gudule Greeting Goswift` holon, so you can see the pattern working
   end to end.

## Start Here

- Want to run the flagship sample now? Read the build instructions below.
- Want the architecture behind the pattern? Inspect `examples/greeting/holon.yaml`,
  `examples/greeting/greeting-daemon/`, and `examples/greeting/greeting-swiftui/`
  together; the example is the current reference architecture.

## What Is a Goswift App?

A Goswift app is a SwiftUI application that ships with a Go backend.
The Go component runs as a headless gRPC daemon; the SwiftUI app is a
gRPC client. On macOS, the daemon is embedded into the `.app` bundle and
launched as a subprocess. On iOS, tvOS, watchOS, and visionOS, the app
connects to an already running daemon over TCP.

| Platform | Transport | Go artifact | Launch |
|----------|-----------|-------------|--------|
| macOS    | `tcp://localhost` | Bundled daemon binary | Embedded `Process()` |
| iOS      | `tcp://<host>:<port>` | External daemon | Remote client |
| tvOS     | `tcp://<host>:<port>` | External daemon | Remote client |
| watchOS  | `tcp://<host>:<port>` | External daemon | Remote client |
| visionOS | `tcp://<host>:<port>` | External daemon | Remote client |

## Gudule Greeting Goswift

The reference implementation in this repository greets users in 56
languages. Source layout:

- `examples/greeting/greeting-daemon/` — Go gRPC daemon
- `examples/greeting/greeting-swiftui/` — SwiftUI frontend

### Build & Run (macOS)

```bash
cd examples/greeting
op build --target macos
open greeting-swiftui/.build/xcode/macos/Build/Products/Debug/GreetingSwiftUI.app
```

### Build Other Apple Targets

```bash
cd examples/greeting
op build --target ios
op build --target tvos
op build --target watchos
op build --target visionos
```

Notes:

- iOS, tvOS, watchOS, and visionOS builds require the corresponding Xcode
  platform components to be installed locally.
- Non-macOS targets do not embed the Go daemon. Set
  `GUDULE_DAEMON_HOST` and `GUDULE_DAEMON_PORT` so the app can reach a
  daemon running elsewhere on your network.
- The current macOS recipe produces a runnable `.app`; the other Apple
  targets produce app bundles when the matching platform SDKs are
  present.

### SwiftUI-Only Sanity Check

```bash
cd examples/greeting/greeting-swiftui
swift build
```

## Project Structure

```text
go-swift-holons/
├── README.md
├── APPS.md                      # Architecture and integration guide
├── scripts/
│   └── build_daemon.sh
└── examples/
    └── greeting/
        ├── holon.yaml           # Composite holon manifest
        ├── greeting-daemon/     # Go daemon source
        └── greeting-swiftui/    # SwiftUI frontend source
```

## Related SDKs

| SDK | Role |
|-----|------|
| [go-holons](https://github.com/organic-programming/go-holons) | Go transport, serving, and identity |
| [grpc-swift](https://github.com/grpc/grpc-swift) | Swift gRPC client |

## See Also

| Recipe | Description |
|--------|-------------|
| [go-dart-holons](https://github.com/organic-programming/go-dart-holons) | Same pattern with Flutter instead of SwiftUI |

## Organic Programming

This recipe is part of the
[Organic Programming](https://github.com/organic-programming/seed)
ecosystem.
