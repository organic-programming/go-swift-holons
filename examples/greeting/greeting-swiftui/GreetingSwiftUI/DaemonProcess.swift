import Foundation

/// Manages the lifecycle of the Go greeting daemon subprocess.
///
/// On macOS the daemon can be launched from the app bundle or the local build tree.
/// On iOS, tvOS, watchOS, and visionOS the app connects to an already running daemon.
@MainActor
final class DaemonProcess: ObservableObject {
    @Published var isRunning = false
    @Published var connectionError: String?

#if os(macOS)
    private var process: Process?
#endif
    private var client: GreetingClient?
    private let configuration = DaemonConfiguration.current

    private var host: String { configuration.host }
    private var port: Int { configuration.port }

    func start() {
        guard client == nil else { return }
        connectionError = nil

#if os(macOS)
        if configuration.launchStrategy == .embeddedIfAvailable, let path = daemonPath() {
            startEmbeddedDaemon(at: path)
            return
        }
#endif
        connectToRemoteDaemon()
    }

    private func connectToRemoteDaemon() {
        client = GreetingClient(host: host, port: port)
        isRunning = true
    }

#if os(macOS)
    private func startEmbeddedDaemon(at path: String) {
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
                client = GreetingClient(host: host, port: port)
            }
        } catch {
            connectionError = "Failed to start bundled daemon: \(error.localizedDescription)"
            connectToRemoteDaemon()
        }
    }

    private func daemonPath() -> String? {
        let fileManager = FileManager.default
        for candidate in daemonCandidates() {
            if fileManager.fileExists(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    private func daemonCandidates() -> [String] {
        var candidates: [String] = []

        if let executableURL = Bundle.main.executableURL {
            let executableDir = executableURL.deletingLastPathComponent().path
            candidates.append((executableDir as NSString).appendingPathComponent("gudule-daemon-greeting-goswift"))
        }

        let bundle = Bundle.main.bundlePath
        let bundleParent = (bundle as NSString).deletingLastPathComponent
        candidates.append((bundleParent as NSString).appendingPathComponent("gudule-daemon-greeting-goswift"))
        candidates.append((bundleParent as NSString).appendingPathComponent("../greeting-daemon/gudule-daemon-greeting-goswift"))

        return candidates
    }
#endif

    func stop() {
#if os(macOS)
        process?.terminate()
        process = nil
#endif
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
#if os(macOS)
        process?.terminate()
#endif
    }
}

private struct DaemonConfiguration {
    enum LaunchStrategy {
        case embeddedIfAvailable
        case remoteOnly
    }

    let host: String
    let port: Int
    let launchStrategy: LaunchStrategy

    static let current = DaemonConfiguration()

    init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        let configuredHost = environment["GUDULE_DAEMON_HOST"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        host = configuredHost.nonEmpty ?? "127.0.0.1"
        port = Int(environment["GUDULE_DAEMON_PORT"] ?? "") ?? 9091
#if os(macOS)
        launchStrategy = environment["GUDULE_DAEMON_AUTOSTART"] == "0" ? .remoteOnly : .embeddedIfAvailable
#else
        launchStrategy = .remoteOnly
#endif
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
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
