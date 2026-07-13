import AppKit
import SwiftUI

/// Presents the first-run onboarding window.
@MainActor
final class OnboardingController: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    func show() {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 560),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to Halo"
        window.contentView = NSHostingView(rootView: OnboardingView(onDone: { [weak self] in
            self?.window?.close()
        }))
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()

        self.window = window
        AppActivation.begin()
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        AppSettings.didOnboard = true
        window = nil
        AppActivation.end()
    }
}
