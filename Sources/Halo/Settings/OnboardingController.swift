import AppKit
import SwiftUI

/// Presents the first-run onboarding window.
@MainActor
final class OnboardingController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var onFinish: (() -> Void)?

    /// - Parameter onFinish: called after the user taps "Get Started" (e.g. to
    ///   demo the wheel), so the button visibly does something.
    func show(onFinish: (() -> Void)? = nil) {
        self.onFinish = onFinish

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
            self?.finish()
        }))
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()

        self.window = window
        AppActivation.begin()
        window.makeKeyAndOrderFront(nil)
    }

    private func finish() {
        let action = onFinish
        window?.close() // fires windowWillClose → cleanup
        // Demo the wheel just after the window closes / focus settles.
        if let action {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { action() }
        }
    }

    func windowWillClose(_ notification: Notification) {
        AppSettings.didOnboard = true
        window = nil
        AppActivation.end()
    }
}
