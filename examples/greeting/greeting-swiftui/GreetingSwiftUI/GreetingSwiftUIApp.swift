import SwiftUI
#if os(macOS)
import AppKit
#endif

@main
struct GreetingSwiftUIApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
    @StateObject private var daemon = DaemonProcess()

    var body: some Scene {
        WindowGroup {
#if os(macOS)
            ContentView(daemon: daemon)
                .frame(minWidth: 480, minHeight: 360)
                .onDisappear { daemon.stop() }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    daemon.stop()
                }
#else
            ContentView(daemon: daemon)
#endif
        }
    }
}

#if os(macOS)
/// Quit the app when the user closes the last window, so that
/// `op run` exits cleanly instead of staying stuck.
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
#endif
