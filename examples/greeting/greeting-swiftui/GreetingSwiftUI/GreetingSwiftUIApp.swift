import SwiftUI

@main
struct GreetingSwiftUIApp: App {
    @StateObject private var daemon = DaemonProcess()

    var body: some Scene {
        WindowGroup {
            ContentView(daemon: daemon)
                .frame(minWidth: 480, minHeight: 360)
        }
    }
}
