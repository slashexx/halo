import AppKit
import SwiftUI

/// Presents the workflow editor in a floating window (activates so text fields
/// and the shortcut recorder receive input).
@MainActor
final class WorkflowEditorController {
    private var window: NSWindow?

    func present(
        name: String,
        steps: [WorkflowStep],
        onSave: @escaping (String, [WorkflowStep]) -> Void
    ) {
        close()

        let view = WorkflowEditorView(
            name: name,
            steps: steps,
            onSave: { [weak self] name, steps in
                self?.close()
                onSave(name, steps)
            },
            onCancel: { [weak self] in self?.close() }
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 580),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Workflow"
        window.contentView = NSHostingView(rootView: view)
        window.isReleasedWhenClosed = false
        window.center()

        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.orderOut(nil)
        window = nil
    }
}
