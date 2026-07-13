import ApplicationServices

/// macOS privacy-permission helpers.
@MainActor
enum Permissions {
    /// Returns whether the process is trusted for Accessibility, prompting the
    /// user (once, non-repeating unless still untrusted) if it isn't. Needed for
    /// synthesising keystrokes and text insertion.
    @discardableResult
    static func ensureAccessibility() -> Bool {
        // Literal key avoids referencing the non-concurrency-safe global CFString.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
