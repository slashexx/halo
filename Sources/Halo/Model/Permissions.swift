import AppKit
import ApplicationServices

/// macOS privacy-permission helpers.
@MainActor
enum Permissions {
    /// Whether the process is trusted for Accessibility (no prompt).
    static var hasAccessibility: Bool { AXIsProcessTrusted() }

    /// Returns whether trusted for Accessibility, prompting the user if not.
    /// Needed for synthesising keystrokes, text insertion, and media keys.
    @discardableResult
    static func ensureAccessibility() -> Bool {
        // Literal key avoids referencing the non-concurrency-safe global CFString.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Opens System Settings → Privacy & Security → Accessibility.
    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Opens System Settings → Privacy & Security → Automation.
    static func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }
}
