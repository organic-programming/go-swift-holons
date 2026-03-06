import SwiftUI

/// Main view: language picker on the left, greeting on the right.
struct ContentView: View {
    @ObservedObject var daemon: DaemonProcess
    @State private var languages: [Language] = []
    @State private var selectedCode: String = ""
    @State private var userName: String = "World"
    @State private var greeting: String = ""
    @State private var error: String?

    var body: some View {
        HStack(spacing: 0) {
            languageList
            Divider()
            greetingPanel
        }
        .task { await loadLanguages() }
    }

    // MARK: - Language List

    private var languageList: some View {
        List(languages, id: \.code, selection: $selectedCode) { lang in
            HStack {
                Text(lang.native)
                    .font(.body)
                Spacer()
                Text(lang.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .tag(lang.code)
        }
        .frame(minWidth: 200)
        .onChange(of: selectedCode) { _, code in
            Task { await greet(code: code) }
        }
    }

    // MARK: - Greeting Panel

    private var greetingPanel: some View {
        VStack(spacing: 16) {
            Spacer()
            if let error {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            } else if greeting.isEmpty {
                Text("Select a language")
                    .foregroundStyle(.secondary)
            } else {
                Text(greeting)
                    .font(.largeTitle)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            HStack {
                TextField("Your name", text: $userName)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                Button("Greet") {
                    Task { await greet(code: selectedCode) }
                }
                .disabled(selectedCode.isEmpty)
            }
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Data Fetching

    private func loadLanguages() async {
        do {
            languages = try await daemon.listLanguages()
            error = nil
        } catch {
            self.error = "Failed to load languages: \(error.localizedDescription)"
        }
    }

    private func greet(code: String) async {
        guard !code.isEmpty else { return }
        do {
            greeting = try await daemon.sayHello(name: userName, langCode: code)
            error = nil
        } catch {
            self.error = "Greeting failed: \(error.localizedDescription)"
        }
    }
}

/// A language returned by the daemon.
struct Language: Identifiable {
    let code: String
    let name: String
    let native: String
    var id: String { code }
}
