import AppKit
import SwiftUI

/// Presents the app picker in a small floating panel. Unlike the overlay, this
/// activates the app so the search field can receive typing.
@MainActor
final class AppPickerController {
    private var panel: NSPanel?

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

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 460),
            styleMask: [.titled, .closable, .utilityWindow, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "Add to Wheel"
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.contentView = NSHostingView(rootView: view)
        panel.center()

        self.panel = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func close() {
        panel?.orderOut(nil)
        panel = nil
    }
}
