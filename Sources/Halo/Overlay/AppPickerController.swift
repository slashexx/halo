import AppKit
import SwiftUI

/// Presents the app picker in a floating window. Switches to a regular
/// activation policy while open so the search field accepts typing.
@MainActor
final class AppPickerController: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    func present(onPick: @escaping (PickResult) -> Void) {
        close()

        let apps = InstalledApps.all()
        let view = AppPickerView(
            apps: apps,
            onPick: { [weak self] result in
                self?.close()
                onPick(result)
            },
            onCancel: { [weak self] in self?.close() }
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 460),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Add to Wheel"
        window.contentView = NSHostingView(rootView: view)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()

        self.window = window
        AppActivation.begin()
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        AppActivation.end()
    }
}
