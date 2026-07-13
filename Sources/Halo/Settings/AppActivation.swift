import AppKit

/// Menu-bar agents (`LSUIElement`) run as `.accessory`, where windows can become
/// key but text fields don't reliably get keyboard focus. While an input window
/// (editor, picker, settings) is open we switch to `.regular` so typing works,
/// then back to `.accessory` when the last one closes. Reference-counted so
/// overlapping windows don't reset early.
@MainActor
enum AppActivation {
    private static var count = 0

    static func begin() {
        count += 1
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func end() {
        count = max(0, count - 1)
        if count == 0 {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
