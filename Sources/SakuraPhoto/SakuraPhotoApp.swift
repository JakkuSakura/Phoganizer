import AppKit
import SwiftUI

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) { NSApp.setActivationPolicy(.regular); NSApp.activate(ignoringOtherApps: true) }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main struct SakuraPhotoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var state = AppState()
    var body: some Scene {
        WindowGroup("SakuraPhoto") { ContentView().environment(state).frame(minWidth: 920, minHeight: 580) }
        .commands { CommandGroup(replacing: .newItem) { } }
    }
}
