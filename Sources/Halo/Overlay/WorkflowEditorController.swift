import AppKit
import SwiftUI

/// Presents the workflow editor in a floating window. Switches the app to a
/// regular activation policy while open so text fields accept typing.
@MainActor
final class WorkflowEditorController: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    func present(
        name: String,
        symbol: String,
        steps: [WorkflowStep],
        onSave: @escaping (String, String, [WorkflowStep]) -> Void
    ) {
        close()

        let view = WorkflowEditorView(
            name: name,
            symbol: symbol,
            steps: steps,
            onSave: { [weak self] name, symbol, steps in
                self?.close()
                onSave(name, symbol, steps)
            },
            onCancel: { [weak self] in self?.close() }
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Workflow"
        window.contentView = NSHostingView(rootView: view)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()

        self.window = window
        AppActivation.begin()
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close() // triggers windowWillClose → AppActivation.end()
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        AppActivation.end()
    }
}
