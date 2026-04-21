import SwiftUI
import AppKit
import A2UI

/// AppKit delegate that forces regular activation policy — needed when
/// launching a SwiftUI app via `swift run` outside a proper .app bundle
/// so the window appears and takes focus.
final class KitchenSinkDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct KitchenSinkApp: App {
    @NSApplicationDelegateAdaptor(KitchenSinkDelegate.self) var delegate

    // Dummy client — the sample doesn't make network calls but views expect
    // an A2UIClient in the environment for event callbacks.
    @State private var client = A2UIClient(url: URL(string: "ws://localhost:0/unused")!)

    var body: some Scene {
        WindowGroup("A2UI Kitchen Sink") {
            KitchenSinkView()
                .environment(client)
                .frame(minWidth: 520, minHeight: 720)
                .preferredColorScheme(.light)
        }
        .windowResizability(.contentSize)
    }
}
