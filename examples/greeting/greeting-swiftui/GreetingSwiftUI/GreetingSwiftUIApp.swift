import SwiftUI

@main
struct GreetingSwiftUIApp: App {
    @StateObject private var daemon = DaemonProcess()

    var body: some Scene {
        WindowGroup {
#if os(macOS)
            ContentView(daemon: daemon)
                .frame(minWidth: 480, minHeight: 360)
#else
            ContentView(daemon: daemon)
#endif
        }
    }
}
