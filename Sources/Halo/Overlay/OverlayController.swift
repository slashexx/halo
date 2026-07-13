import AppKit
import SwiftUI

/// Shows/hides the radial overlay, positions it, and routes slot interactions:
/// activating (run an action or add to an empty slot), editing, and clearing.
@MainActor
final class OverlayController {
    private let panelSize = NSSize(width: 420, height: 420)
    private let model = RadialMenuModel()
    private let picker = AppPickerController()

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
        if let index = model.highlightedIndex {
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
            onEdit: { [weak self] index in self?.editSlot(index) },
            onClear: { [weak self] index in self?.model.setSlot(index, to: nil) },
            onBack: { [weak self] in self?.model.popToRoot() },
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

    /// Left-click / Return / release on a node.
    private func activate(_ index: Int) {
        guard let node = model.node(at: index) else { return }

        switch node {
        case .slot(let slotIndex, let item):
            guard let item else { editSlot(slotIndex); return } // empty → add
            if item.kind == .clipboard { model.enterClipboard(); return } // stay open
            if let action = item.action {
                hide()
                // Execute once focus is back on the underlying app so keystroke /
                // text injection lands there, not on our (now hidden) panel.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { action.execute() }
            } else {
                hide()
            }

        case .clip(let entry):
            ClipboardMonitor.shared.makeCurrent(entry)
            hide()
        }
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
                HaloAction.runAppleScript(
                    #"display notification "Workflow builder is coming soon" with title "Halo""#
                ).execute()
            }
        }
    }

    // MARK: - Event monitors

    private func installMonitors() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            switch event.keyCode {
            case 53: // Escape — leave the sub-menu first, then dismiss.
                if self.model.level == .clipboard {
                    self.model.popToRoot()
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
