import AppKit
import SwiftUI

/// Shows and hides the radial overlay, positions it at the cursor, and routes
/// selection / dismissal. In Phase 1 activating an item just logs; Phase 2 will
/// execute a real action.
@MainActor
final class OverlayController {
    private let panelSize = NSSize(width: 420, height: 420)
    private let model = RadialMenuModel()

    private var panel: OverlayPanel?
    private var keyMonitor: Any?
    private var globalMouseMonitor: Any?
    private(set) var isVisible = false

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        showPanel { [weak self] panel in self?.positionForCurrentSetting(panel) }
    }

    /// Summons the menu centered on the active screen regardless of the setting.
    /// Used by the debug launch hook.
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
        removeMonitors()
    }

    // MARK: - Setup

    private func makePanel() -> OverlayPanel {
        let panel = OverlayPanel(size: panelSize)
        let root = RadialMenuView(
            model: model,
            onSelect: { [weak self] item in self?.activate(item) },
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

    /// Centers the panel on whichever screen currently contains the cursor
    /// (so it lands on the active display in a multi-monitor setup).
    private func positionAtScreenCenter(_ panel: OverlayPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
        guard let frame = screen?.frame else { return }
        let origin = NSPoint(x: frame.midX - panelSize.width / 2,
                             y: frame.midY - panelSize.height / 2)
        panel.setFrameOrigin(origin)
    }

    private func activate(_ item: MenuItem) {
        hide()
        NSLog("Halo: activated '%@'", item.title)
    }

    // MARK: - Event monitors

    private func installMonitors() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            switch event.keyCode {
            case 53: // Escape
                self.hide()
                return nil
            case 36, 76: // Return / Enter
                if let index = self.model.highlightedIndex {
                    self.activate(self.model.items[index])
                }
                return nil
            default:
                return event
            }
        }

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
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
