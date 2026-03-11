# STATUS - go-swift-holons (macOS)

Date: 2026-03-11
Host: macOS 15.7.2 (arm64)

## Summary
The macOS greeting bundle packaging has been fixed in `examples/greeting/holon.yaml`.
`op build --target macos` now produces a valid, signed `GreetingSwiftUI.app`
with a real `Info.plist`, a populated `Contents/Resources/`, and a signed embedded
Go daemon.

## Root Cause Found
The previous macOS recipe did not build a real app bundle. It only copied:

- `GreetingSwiftUI` into `Contents/MacOS/`
- `gudule-daemon-greeting-goswift` into `Contents/MacOS/`

That left the `.app` without:

- `Contents/Info.plist`
- a valid bundle signature
- copied resource bundles
- a bundle-local runtime layout for packaged launch

## Fix Applied
`examples/greeting/holon.yaml` now rebuilds the macOS bundle after `xcodebuild`:

1. removes any previous `GreetingSwiftUI.app`
2. creates `Contents/MacOS`, `Contents/Resources`, and `Contents/lib`
3. copies the SwiftUI executable and embedded daemon into `Contents/MacOS`
4. copies any `*.bundle` outputs into `Contents/Resources`
5. copies `PackageFrameworks/.` into `Contents/lib`
6. writes `Contents/Info.plist`
7. runs `codesign --force --deep --sign - GreetingSwiftUI.app`

## Verification Result
- `op build --target macos` -> PASS
- `codesign --verify --deep --strict --verbose=4 GreetingSwiftUI.app` -> PASS
- `plutil -p GreetingSwiftUI.app/Contents/Info.plist` -> PASS
- `open -n GreetingSwiftUI.app` -> PASS
- window server probe -> `GreetingSwiftUI` windows observed
- embedded daemon observed after bundle launch:
  - `gudule-daemon-greeting-goswift serve --listen stdio://`
- daemon exits after app termination -> PASS

## Notes
The automated audit confirmed bundle launch plus embedded daemon lifecycle.
Manual UI interaction (clicking the Greet button and reading the returned greeting)
was not re-executed in this environment.
