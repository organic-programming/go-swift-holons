import Foundation

/// Manages the lifecycle of the Go greeting daemon subprocess.
///
/// On macOS the daemon communicates via a TCP listener on localhost.
/// The process is launched when `start()` is called and terminated on deinit.
@MainActor
final class DaemonProcess: ObservableObject {
    @Published var isRunning = false
    @Published var connectionError: String?

    private var process: Process?
    private var client: GreetingClient?

    /// The localhost port the daemon listens on.
    private let port: Int = 9091

    /// Locates the daemon binary bundled alongside the app or in the build dir.
    private var daemonPath: String {
        // In a built .app bundle, the daemon sits next to the app binary.
        let bundle = Bundle.main.bundlePath
        let bundledPath = (bundle as NSString)
            .deletingLastPathComponent
            .appending("/gudule-daemon-greeting-goswift")

        if FileManager.default.fileExists(atPath: bundledPath) {
            return bundledPath
        }

        // Fallback: look in the greeting-daemon directory (dev mode).
        let devPath = (bundle as NSString)
            .deletingLastPathComponent
            .appending("/../greeting-daemon/gudule-daemon-greeting-goswift")
        return devPath
    }

    func start() {
        guard process == nil else { return }
        let path = daemonPath
        guard FileManager.default.fileExists(atPath: path) else {
            connectionError = "Daemon binary not found at \(path). Run `op build` first."
            return
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = ["serve", "--listen", "tcp://:\(port)"]

        do {
            try proc.run()
            process = proc
            isRunning = true

            // Give the daemon a moment to start listening.
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                client = GreetingClient(host: "localhost", port: port)
            }
        } catch {
            connectionError = "Failed to start daemon: \(error.localizedDescription)"
        }
    }

    func stop() {
        process?.terminate()
        process = nil
        client = nil
        isRunning = false
    }

    // MARK: - RPC Wrappers

    func listLanguages() async throws -> [Language] {
        if client == nil { start() }
        // Wait for client to initialize.
        for _ in 0..<10 {
            if client != nil { break }
            try? await Task.sleep(for: .milliseconds(200))
        }
        guard let client else {
            throw DaemonError.notConnected
        }
        return try await client.listLanguages()
    }

    func sayHello(name: String, langCode: String) async throws -> String {
        guard let client else {
            throw DaemonError.notConnected
        }
        return try await client.sayHello(name: name, langCode: langCode)
    }

    deinit {
        process?.terminate()
    }
}

enum DaemonError: LocalizedError {
    case notConnected

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to the greeting daemon"
        }
    }
}
