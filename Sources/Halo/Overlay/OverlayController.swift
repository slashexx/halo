import AppKit
import SwiftUI

/// Shows/hides the radial overlay, positions it, and routes slot interactions:
/// activating (run an action or add to an empty slot), editing, and clearing.
@MainActor
final class OverlayController {
    // Wide enough for the wheel plus the clipboard list beside it.
    private let panelSize = NSSize(width: 1000, height: 560)
    private let model = RadialMenuModel()
    private let picker = AppPickerController()
    private let workflowEditor = WorkflowEditorController()

    private var panel: OverlayPanel?
    private var keyMonitor: Any?
    private var globalMouseMonitor: Any?
    private(set) var isVisible = false

    // Gesture state for hold-and-release / tap-to-stick.
    private var pressUptime: TimeInterval = 0
    private var awaitingClick = false
    private let tapThreshold: TimeInterval = 0.3

    func toggle() {
        isVisible ? hide() : show()
    }

    // MARK: - Trigger (from the ⌥Tab hot key)

    func handlePress() {
        switch AppSettings.gestureMode {
        case .pressToggle:
            toggle()
        case .holdRelease:
            if !isVisible { pressUptime = ProcessInfo.processInfo.systemUptime; show() }
        case .both:
            if isVisible {
                hide() // a second press closes a sticky wheel
            } else {
                pressUptime = ProcessInfo.processInfo.systemUptime
                awaitingClick = false
                show()
            }
        }
    }

    func handleRelease() {
        switch AppSettings.gestureMode {
        case .pressToggle:
            break
        case .holdRelease:
            if isVisible { activateHighlightedOrHide() }
        case .both:
            guard isVisible, !awaitingClick else { return }
            let held = ProcessInfo.processInfo.systemUptime - pressUptime
            if held < tapThreshold {
                awaitingClick = true // quick tap → sticky, wait for a click
            } else {
                activateHighlightedOrHide()
            }
        }
    }

    private func activateHighlightedOrHide() {
        if model.clipboardOpen {
            if let clipIndex = model.highlightedClipIndex {
                activateClip(clipIndex)
            } else {
                hide()
            }
        } else if let index = model.highlightedIndex {
            activate(index)
        } else {
            hide()
        }
    }

    func show() {
        showPanel { [weak self] panel in self?.positionForCurrentSetting(panel) }
    }

    /// Summons the menu centered on the active screen regardless of the setting.
    func showAtScreenCenter() {
        showPanel { [weak self] panel in self?.positionAtScreenCenter(panel) }
    }

    private func showPanel(position: (OverlayPanel) -> Void) {
        let panel = panel ?? makePanel()
        self.panel = panel

        model.reset()
        position(panel)

        panel.orderFrontRegardless()
        panel.makeKey()
        isVisible = true

        installMonitors()
    }

    func hide() {
        guard isVisible else { return }
        panel?.orderOut(nil)
        isVisible = false
        awaitingClick = false
        removeMonitors()
    }

    // MARK: - Setup

    private func makePanel() -> OverlayPanel {
        let panel = OverlayPanel(size: panelSize)
        let root = RadialMenuView(
            model: model,
            onActivate: { [weak self] index in self?.activate(index) },
            onActivateClip: { [weak self] index in self?.activateClip(index) },
            onEdit: { [weak self] index in self?.editSlot(index) },
            onEditWorkflow: { [weak self] index in self?.editWorkflow(index) },
            onClear: { [weak self] index in self?.model.setSlot(index, to: nil) },
            onCloseClipboard: { [weak self] in self?.model.closeClipboard() },
            onDismiss: { [weak self] in self?.hide() }
        )
        let hosting = NSHostingView(rootView: root)
        hosting.frame = NSRect(origin: .zero, size: panelSize)
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
        return panel
    }

    private func positionForCurrentSetting(_ panel: OverlayPanel) {
        switch AppSettings.placement {
        case .center: positionAtScreenCenter(panel)
        case .cursor: positionAtCursor(panel)
        }
    }

    private func positionAtCursor(_ panel: OverlayPanel) {
        let mouse = NSEvent.mouseLocation
        let origin = NSPoint(x: mouse.x - panelSize.width / 2,
                             y: mouse.y - panelSize.height / 2)
        panel.setFrameOrigin(origin)
    }

    /// Centers the panel on whichever screen currently contains the cursor.
    private func positionAtScreenCenter(_ panel: OverlayPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
        guard let frame = screen?.frame else { return }
        let origin = NSPoint(x: frame.midX - panelSize.width / 2,
                             y: frame.midY - panelSize.height / 2)
        panel.setFrameOrigin(origin)
    }

    // MARK: - Slot interactions

    /// Left-click / Return / release on a ring slot.
    private func activate(_ index: Int) {
        guard let item = model.item(at: index) else { editSlot(index); return } // empty → add
        if item.kind == .clipboard { model.openClipboard(); return }            // stays open, on the side
        if let action = item.action {
            hide()
            // Execute once focus is back on the underlying app so keystroke /
            // text injection lands there, not on our (now hidden) panel.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { action.execute() }
        } else {
            hide()
        }
    }

    /// Select a clipboard entry: make it the current clipboard and dismiss.
    private func activateClip(_ index: Int) {
        guard model.clipboardEntries.indices.contains(index) else { return }
        ClipboardMonitor.shared.makeCurrent(model.clipboardEntries[index])
        hide()
    }

    /// Open the app picker to fill or replace a slot.
    private func editSlot(_ index: Int) {
        hide()
        picker.present { [weak self] result in
            guard let self else { return }
            switch result {
            case .app(let app):
                let item = MenuItem(
                    title: app.name,
                    icon: .appIcon(path: app.path),
                    action: .launchApp(name: app.name)
                )
                self.model.setSlot(index, to: item)
            case .clipboard:
                self.model.setSlot(index, to: MenuItem(
                    title: "Clipboard",
                    icon: .symbol("doc.on.clipboard"),
                    kind: .clipboard
                ))
            case .newWorkflow:
                self.openWorkflowEditor(index: index, name: "Workflow", steps: [])
            }
        }
    }

    /// Edit an existing workflow slot (its action is a `.chain`).
    private func editWorkflow(_ index: Int) {
        guard let item = model.item(at: index),
              case .chain(let actions)? = item.action else { return }
        hide()
        openWorkflowEditor(index: index, name: item.title, steps: actions.map(WorkflowStep.init(action:)))
    }

    private func openWorkflowEditor(index: Int, name: String, steps: [WorkflowStep]) {
        workflowEditor.present(name: name, steps: steps) { [weak self] name, steps in
            guard let self else { return }
            let actions = steps.map(\.action)
            let title = name.trimmingCharacters(in: .whitespaces)
            self.model.setSlot(index, to: MenuItem(
                title: title.isEmpty ? "Workflow" : title,
                icon: .symbol("square.stack.3d.up.fill"),
                action: .chain(actions)
            ))
        }
    }

    // MARK: - Event monitors

    private func installMonitors() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            switch event.keyCode {
            case 53: // Escape — close the clipboard side-panel first, then dismiss.
                if self.model.clipboardOpen {
                    self.model.closeClipboard()
                } else {
                    self.hide()
                }
                return nil
            case 36, 76: // Return / Enter
                if let index = self.model.highlightedIndex {
                    self.activate(index)
                }
                return nil
            default:
                return event
            }
        }

        // Dismiss on a click outside the panel. Left-only so right-clicks (which
        // open a slot's context menu inside the panel) are never misread.
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown]
        ) { [weak self] _ in
            self?.hide()
        }
    }

    private func removeMonitors() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        if let globalMouseMonitor { NSEvent.removeMonitor(globalMouseMonitor) }
        keyMonitor = nil
        globalMouseMonitor = nil
    }
}
