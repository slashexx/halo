import AppKit
import SwiftUI

/// Presents the Settings window. Reuses one instance; switches to a regular
/// activation policy while open so controls behave normally.
@MainActor
final class SettingsController: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    func show() {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Halo Settings"
        window.contentView = NSHostingView(rootView: SettingsView())
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()

        self.window = window
        AppActivation.begin()
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        AppActivation.end()
    }
}
