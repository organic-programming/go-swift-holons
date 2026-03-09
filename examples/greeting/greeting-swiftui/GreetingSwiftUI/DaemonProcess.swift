import Foundation
#if os(macOS)
import Darwin
#endif

/// Manages the lifecycle of the Go greeting daemon subprocess.
///
/// On macOS the daemon is launched as a bundled TCP subprocess.
/// On iOS, tvOS, watchOS, and visionOS the app connects to an already running daemon.
@MainActor
final class DaemonProcess: ObservableObject {
    @Published var isRunning = false
    @Published var connectionError: String?

    private var client: GreetingClient?
    private let configuration = DaemonConfiguration.current
#if os(macOS)
    private var daemonProcess: Process?
#endif

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
        do {
            let launched = try launchDaemon(binaryPath: path)
            daemonProcess = launched.process
            client = try GreetingClient.direct(host: launched.host, port: launched.port)
            isRunning = true
        } catch {
            if let process = daemonProcess {
                stopDaemonProcess(process)
            }
            daemonProcess = nil
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

    private func launchDaemon(binaryPath: String) throws -> (process: Process, host: String, port: Int) {
        let listenHost = "127.0.0.1"
        let listenPort = port
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = ["serve", "--listen", "tcp://\(listenHost):\(listenPort)"]
        process.standardOutput = FileHandle.nullDevice

        let stderr = Pipe()
        let collector = StringCollector()
        let queue = LineQueue()
        process.standardError = stderr
        startLineReader(handle: stderr.fileHandleForReading, queue: queue, collector: collector)

        try process.run()

        do {
            try waitForTCPAccept(
                process: process,
                host: listenHost,
                port: listenPort,
                collector: collector,
                timeout: 5.0
            )
            Thread.sleep(forTimeInterval: 1.0)
            return (process, listenHost, listenPort)
        } catch {
            stopDaemonProcess(process)
            throw error
        }
    }

    private func waitForTCPAccept(
        process: Process,
        host: String,
        port: Int,
        collector: StringCollector,
        timeout: TimeInterval
    ) throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if socketConnects(host: host, port: port) {
                return
            }
            if !process.isRunning {
                let stderr = collector.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !stderr.isEmpty {
                    throw DaemonLaunchError.startupFailed(stderr)
                }
                throw DaemonLaunchError.startupFailed("daemon exited before accepting TCP connections")
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        throw DaemonLaunchError.startupTimedOut
    }

#endif

    func stop() {
        let currentClient = client
        client = nil

        do {
            try currentClient?.close()
        } catch {
            connectionError = "Failed to stop daemon connection: \(error.localizedDescription)"
        }

#if os(macOS)
        let process = daemonProcess
        daemonProcess = nil
        if let process {
            stopDaemonProcess(process)
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
        if let daemonProcess {
            stopDaemonProcess(daemonProcess)
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

#if os(macOS)
private final class LineQueue: @unchecked Sendable {
    private let lock = NSLock()
    private let semaphore = DispatchSemaphore(value: 0)
    private var lines: [String] = []

    func push(_ line: String) {
        lock.lock()
        lines.append(line)
        lock.unlock()
        semaphore.signal()
    }

    func pop(timeout: TimeInterval) -> String? {
        let result = semaphore.wait(timeout: .now() + timeout)
        guard result == .success else {
            return nil
        }

        lock.lock()
        defer { lock.unlock() }
        guard !lines.isEmpty else {
            return nil
        }
        return lines.removeFirst()
    }
}

private final class StringCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var lines: [String] = []

    func append(_ line: String) {
        lock.lock()
        lines.append(line)
        lock.unlock()
    }

    var text: String {
        lock.lock()
        defer { lock.unlock() }
        return lines.joined(separator: "\n")
    }
}

private func startLineReader(handle: FileHandle, queue: LineQueue, collector: StringCollector) {
    DispatchQueue.global(qos: .utility).async {
        var buffer = Data()

        while true {
            let chunk = handle.availableData
            if chunk.isEmpty {
                let trailing = String(data: buffer, encoding: .utf8)?
                    .trimmingCharacters(in: .newlines) ?? ""
                if !trailing.isEmpty {
                    collector.append(trailing)
                    queue.push(trailing)
                }
                return
            }

            buffer.append(chunk)
            while let newline = buffer.firstIndex(of: 0x0A) {
                let lineData = buffer[..<newline]
                buffer.removeSubrange(...newline)
                guard let line = String(data: lineData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                    !line.isEmpty else {
                    continue
                }
                collector.append(line)
                queue.push(line)
            }
        }
    }
}

private func socketConnects(host: String, port: Int) -> Bool {
    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = in_port_t(UInt16(port).bigEndian)

    guard inet_pton(AF_INET, host, &address.sin_addr) == 1 else {
        return false
    }

    let descriptor = socket(AF_INET, SOCK_STREAM, 0)
    guard descriptor >= 0 else {
        return false
    }
    defer { close(descriptor) }

    var socketAddress = address
    let result = withUnsafePointer(to: &socketAddress) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    return result == 0
}

private enum DaemonLaunchError: LocalizedError {
    case startupFailed(String)
    case startupTimedOut

    var errorDescription: String? {
        switch self {
        case let .startupFailed(message):
            return message
        case .startupTimedOut:
            return "timed out waiting for the daemon to advertise a TCP address"
        }
    }
}

private func stopDaemonProcess(_ process: Process) {
    guard process.isRunning else { return }

    process.terminate()

    let gracefulDeadline = Date().addingTimeInterval(2.0)
    while process.isRunning && Date() < gracefulDeadline {
        Thread.sleep(forTimeInterval: 0.05)
    }

    if process.isRunning {
        kill(process.processIdentifier, SIGKILL)
        let forcedDeadline = Date().addingTimeInterval(1.0)
        while process.isRunning && Date() < forcedDeadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
    }
}
#endif
