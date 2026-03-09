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
gRPC client. On macOS, the daemon is embedded into the `.app` bundle,
staged as a discoverable holon, and launched through
`swift-holons connect(slug)`. On iOS, tvOS, watchOS, and visionOS, the
app connects to an already running daemon through the SDK's direct-dial
`connect(host:port)` path.

| Platform | Transport | Go artifact | Launch |
|----------|-----------|-------------|--------|
| macOS    | `connect("gudule-daemon-greeting-goswift")` | Bundled daemon binary | Auto-started holon |
| iOS      | `connect("<host>:<port>")` | External daemon | Remote client |
| tvOS     | `connect("<host>:<port>")` | External daemon | Remote client |
| watchOS  | `connect("<host>:<port>")` | External daemon | Remote client |
| visionOS | `connect("<host>:<port>")` | External daemon | Remote client |

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
op build --target all
op build --target ios
op build --target ios-simulator
op build --target tvos
op build --target watchos
op build --target visionos
```

Notes:

- iOS, tvOS, watchOS, and visionOS builds require the corresponding Xcode
  platform components to be installed locally.
- `op build --target all` works for this recipe and walks every declared
  recipe target in order, stopping on the first target that fails.
- Non-macOS targets do not embed the Go daemon. Set
  `GUDULE_DAEMON_HOST` and `GUDULE_DAEMON_PORT` so the app can reach a
  daemon running elsewhere on your network.
- `macos` produces a runnable `.app` with the embedded daemon.
- `ios-simulator` produces a runnable `.app` wrapper around the SwiftPM
  executable so it can be installed with `simctl`.
- `ios`, `tvos`, `watchos`, and `visionos` currently resolve to the
  platform executable inside Xcode derived data.

### Build & Launch (iOS Simulator)

Start a daemon on the Mac host:

```bash
cd examples/greeting/greeting-daemon
go run ./cmd/daemon serve --listen tcp://127.0.0.1:9091
```

Build the simulator app bundle:

```bash
cd ../
op build --target ios-simulator
```

Boot the Simulator, install the app, then launch it with the daemon host
and port in the process environment:

```bash
open -a Simulator
xcrun simctl boot "iPhone 16"

APP="greeting-swiftui/.build/xcode/ios-simulator/Build/Products/Debug-iphonesimulator/GreetingSwiftUI.app"
BUNDLE_ID="org.organicprogramming.greeting-swiftui"

xcrun simctl install booted "$APP"
SIMCTL_CHILD_GUDULE_DAEMON_HOST=127.0.0.1 \
SIMCTL_CHILD_GUDULE_DAEMON_PORT=9091 \
xcrun simctl launch booted "$BUNDLE_ID" \
  --console \
  --terminate-running-process
```

Notes:

- On iOS Simulator, `127.0.0.1` is the Mac host, so the app can reach a
  daemon listening on the machine running Xcode.
- `op build --target ios-simulator` creates the installable `.app`
  wrapper in `greeting-swiftui/.build/xcode/ios-simulator/Build/Products/Debug-iphonesimulator/`.
- If a simulator is already booted, replace `xcrun simctl boot "iPhone 16"`
  with `xcrun simctl bootstatus booted -b`.

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
| [swift-holons](https://github.com/organic-programming/swift-holons) | Swift connect and runtime discovery |

## See Also

| Recipe | Description |
|--------|-------------|
| [go-dart-holons](https://github.com/organic-programming/go-dart-holons) | Same pattern with Flutter instead of SwiftUI |

## Organic Programming

This recipe is part of the
[Organic Programming](https://github.com/organic-programming/seed)
ecosystem.
