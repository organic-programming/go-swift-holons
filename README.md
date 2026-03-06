# GOSWIFT (`go-swiftui-holons`)

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
- Want the architecture behind the pattern? Read [APPS.md](APPS.md).

## What Is a Goswift App?

A Goswift app is a SwiftUI application that ships with a Go backend.
The Go component runs as a headless gRPC daemon; the SwiftUI app is a
gRPC client. On macOS, the daemon is launched as a subprocess and
reached over `tcp://localhost`.

| Platform | Transport | Go artifact | Launch |
|----------|-----------|-------------|--------|
| macOS    | `tcp://`  | Standalone binary | `Process()` |

## Gudule Greeting Goswift

The reference implementation in this repository greets users in 56
languages. Source layout:

- `examples/greeting/greeting-daemon/` — Go gRPC daemon
- `examples/greeting/greeting-swiftui/` — SwiftUI frontend

### Build & Run (macOS)

```bash
# 1. Build the daemon
cd examples/greeting/greeting-daemon
go build -o gudule-daemon-greeting-goswift ./cmd/daemon

# 2. Build the SwiftUI app
cd ../greeting-swiftui
swift build

# 3. Run the daemon
../greeting-daemon/gudule-daemon-greeting-goswift serve &

# 4. Run the app
.build/debug/GreetingSwiftUI
```

Or, with `op`:

```bash
cd examples/greeting
op build --target macos
```

## Project Structure

```text
go-swiftui-holons/
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
