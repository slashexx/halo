import AppKit
import Carbon.HIToolbox

/// Owns app-wide lifecycle: the menu-bar item, the global hot key, and the
/// overlay controller.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let overlay = OverlayController()

    private var placementCenterItem: NSMenuItem?
    private var placementCursorItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupHotkey()
        ClipboardMonitor.shared.start() // begin remembering copies immediately

        // Debug hook: HALO_DEBUG_SHOW=1 summons the menu at screen center on
        // launch so it can be inspected without the hot key.
        if ProcessInfo.processInfo.environment["HALO_DEBUG_SHOW"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.overlay.showAtScreenCenter()
            }
        }

        // Debug hook: HALO_DEBUG_SNAPSHOT=<path> renders the menu to a PNG
        // in-process and quits. No Screen Recording permission required.
        if let path = ProcessInfo.processInfo.environment["HALO_DEBUG_SNAPSHOT"] {
            DebugSnapshot.render(to: path)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private func setupHotkey() {
        // Trigger: ⌥Tab. A Carbon hot key, so no Accessibility permission needed.
        HotkeyManager.shared.onPressed = { [weak self] in
            self?.overlay.toggle()
        }
        HotkeyManager.shared.register(keyCode: UInt32(kVK_Tab), modifiers: UInt32(optionKey))
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(
                systemSymbolName: "circle.hexagongrid",
                accessibilityDescription: "Halo"
            )
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "Halo — dev build", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "Press ⌥Tab to open", action: nil, keyEquivalent: "")
        menu.addItem(.separator())

        let placementParent = NSMenuItem(title: "Open Menu", action: nil, keyEquivalent: "")
        let placementMenu = NSMenu()
        let centerItem = NSMenuItem(title: "At Center of Screen",
                                    action: #selector(setPlacementCenter), keyEquivalent: "")
        let cursorItem = NSMenuItem(title: "At Cursor",
                                    action: #selector(setPlacementCursor), keyEquivalent: "")
        placementMenu.addItem(centerItem)
        placementMenu.addItem(cursorItem)
        placementParent.submenu = placementMenu
        menu.addItem(placementParent)
        self.placementCenterItem = centerItem
        self.placementCursorItem = cursorItem

        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit Halo",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        item.menu = menu

        self.statusItem = item
        refreshPlacementChecks()
    }

    @objc private func setPlacementCenter() {
        AppSettings.placement = .center
        refreshPlacementChecks()
    }

    @objc private func setPlacementCursor() {
        AppSettings.placement = .cursor
        refreshPlacementChecks()
    }

    private func refreshPlacementChecks() {
        placementCenterItem?.state = AppSettings.placement == .center ? .on : .off
        placementCursorItem?.state = AppSettings.placement == .cursor ? .on : .off
    }
}
