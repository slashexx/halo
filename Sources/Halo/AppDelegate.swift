import AppKit
import Carbon.HIToolbox

/// Owns app-wide lifecycle: the menu-bar item, the global hot key, the overlay
/// controller, settings, and first-run onboarding.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let overlay = OverlayController()
    private let settings = SettingsController()
    private let onboarding = OnboardingController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupHotkey()
        ClipboardMonitor.shared.start() // begin remembering copies immediately

        if ProcessInfo.processInfo.environment["HALO_DEBUG_SHOW"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.overlay.showAtScreenCenter()
            }
        }
        if let path = ProcessInfo.processInfo.environment["HALO_DEBUG_SNAPSHOT"] {
            DebugSnapshot.render(to: path)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                NSApplication.shared.terminate(nil)
            }
            return
        }

        // First launch → welcome + permissions.
        if !AppSettings.didOnboard {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.showOnboarding()
            }
        }
    }

    private func showOnboarding() {
        // "Get Started" closes the window and pops the wheel so it visibly works.
        onboarding.show(onFinish: { [weak self] in self?.overlay.showAtScreenCenter() })
    }

    /// Halo is a menu-bar agent with no window, so opening it again from
    /// Spotlight/Finder/Dock would otherwise do nothing visible. Show the
    /// welcome window instead — it explains the menu-bar icon and ⌥Tab.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showOnboarding()
        return true
    }

    private func setupHotkey() {
        // Trigger: ⌥Tab. A Carbon hot key, so no Accessibility permission needed.
        // Only the press opens the wheel; "release to pick/close" is driven off
        // the Option key while the wheel is open (see OverlayController).
        HotkeyManager.shared.onPressed = { [weak self] in self?.overlay.handlePress() }
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

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"

        let menu = NSMenu()
        menu.addItem(withTitle: "Halo \(version)", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "Press ⌥Tab to open", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(withTitle: "Welcome to Halo…", action: #selector(openOnboarding), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "GitHub", action: #selector(openGitHub), keyEquivalent: "")
        menu.addItem(withTitle: "Send Feedback…", action: #selector(sendFeedback), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit Halo",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        item.menu = menu
        self.statusItem = item
    }

    @objc private func openSettings() { settings.show() }
    @objc private func openOnboarding() { onboarding.show() }

    @objc private func openGitHub() {
        NSWorkspace.shared.open(URL(string: "https://github.com/slashexx/halo")!)
    }

    @objc private func sendFeedback() {
        NSWorkspace.shared.open(URL(string: "https://github.com/slashexx/halo/issues/new")!)
    }
}
