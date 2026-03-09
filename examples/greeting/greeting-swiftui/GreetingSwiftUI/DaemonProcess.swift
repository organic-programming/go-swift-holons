import Foundation
#if os(macOS)
import Holons
#endif

/// Manages the lifecycle of the Go greeting daemon subprocess.
///
/// On macOS the daemon is staged as a discoverable holon and launched via `connect(slug)`.
/// On iOS, tvOS, watchOS, and visionOS the app connects to an already running daemon.
@MainActor
final class DaemonProcess: ObservableObject {
    @Published var isRunning = false
    @Published var connectionError: String?

    private static let holonSlug = "gudule-daemon-greeting-goswift"
    private static let holonUUID = "2b519b2f-7a34-4957-a0ab-58c1b7fa9f95"
    private static let familyName = "Greeting-Goswift"

    private var client: GreetingClient?
    private var stageRoot: URL?
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
        do {
            client = try GreetingClient.direct(host: host, port: port)
            isRunning = true
        } catch {
            connectionError = "Failed to connect to daemon at \(host):\(port): \(error.localizedDescription)"
            isRunning = false
        }
    }

#if os(macOS)
    private func startEmbeddedDaemon(at path: String) {
        var root: URL?
        do {
            root = try stageHolonRoot(binaryPath: path)
            guard let root else {
                throw CocoaError(.fileNoSuchFile)
            }
            stageRoot = root

            let previousDirectory = FileManager.default.currentDirectoryPath
            guard FileManager.default.changeCurrentDirectoryPath(root.path) else {
                throw CocoaError(.fileNoSuchFile)
            }
            defer {
                FileManager.default.changeCurrentDirectoryPath(previousDirectory)
            }

            let channel = try connect(Self.holonSlug)
            client = GreetingClient(channel: channel) {
                try disconnect(channel)
            }
            isRunning = true
        } catch {
            if let root {
                try? FileManager.default.removeItem(at: root)
            }
            stageRoot = nil
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

    private func stageHolonRoot(binaryPath: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("greeting-goswift-holon-\(UUID().uuidString)", isDirectory: true)
        let holonDir = root
            .appendingPathComponent("holons", isDirectory: true)
            .appendingPathComponent(Self.holonSlug, isDirectory: true)
        try FileManager.default.createDirectory(at: holonDir, withIntermediateDirectories: true)
        try buildManifest(binaryPath: binaryPath)
            .write(to: holonDir.appendingPathComponent("holon.yaml"), atomically: true, encoding: .utf8)
        return root
    }

    private func buildManifest(binaryPath: String) -> String {
        let escapedPath = binaryPath
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return """
schema: holon/v0
uuid: "\(Self.holonUUID)"
given_name: greeting-daemon
family_name: "\(Self.familyName)"
motto: Greets users in 56 languages — a Goswift recipe example.
composer: B. ALTER
clade: deterministic/pure
status: draft
born: "2026-03-06"
generated_by: manual
kind: native
build:
  runner: go-module
artifacts:
  binary: "\(escapedPath)"
""" + "\n"
    }
#endif

    func stop() {
        let currentClient = client
        client = nil
        let root = stageRoot
        stageRoot = nil

        do {
            try currentClient?.close()
        } catch {
            connectionError = "Failed to stop daemon connection: \(error.localizedDescription)"
        }

#if os(macOS)
        if let root {
            try? FileManager.default.removeItem(at: root)
        }
#endif
        isRunning = false
    }

    // MARK: - RPC Wrappers

    func listLanguages() async throws -> [Language] {
        if client == nil { start() }
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
        try? client?.close()
        if let stageRoot {
            try? FileManager.default.removeItem(at: stageRoot)
        }
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
