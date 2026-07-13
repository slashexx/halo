import AppKit
import CoreGraphics

/// Executes `HaloAction`s. Keystroke/text actions gate on Accessibility; the
/// rest need no special permission.
@MainActor
enum ActionRunner {
    static func run(_ action: HaloAction) {
        if action.needsAccessibility, !Permissions.ensureAccessibility() {
            NSLog("Halo: this action needs Accessibility. Enable Halo in "
                + "System Settings › Privacy & Security › Accessibility, then try again.")
            return
        }

        switch action {
        case .launchApp(let name): launchApp(name)
        case .openURL(let target): openTarget(target)
        case .keyboardShortcut(let combo): postCombo(combo)
        case .runAppleScript(let source): runAppleScript(source)
        case .runShell(let command): runShell(command)
        case .insertText(let text): typeText(text)
        }
    }

    // MARK: - Launch / open

    private static func launchApp(_ name: String) {
        runProcess("/usr/bin/open", ["-a", name])
    }

    private static func openTarget(_ target: String) {
        if let url = URL(string: target), url.scheme != nil {
            NSWorkspace.shared.open(url)
        } else {
            let expanded = (target as NSString).expandingTildeInPath
            NSWorkspace.shared.open(URL(fileURLWithPath: expanded))
        }
    }

    // MARK: - Scripts

    private static func runAppleScript(_ source: String) {
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error {
            NSLog("Halo: AppleScript error: %@", error)
        }
    }

    private static func runShell(_ command: String) {
        runProcess("/bin/zsh", ["-lc", command])
    }

    private static func runProcess(_ launchPath: String, _ arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        do {
            try process.run() // fire-and-forget; we don't block on completion
        } catch {
            NSLog("Halo: failed to run %@: %@", launchPath, error.localizedDescription)
        }
    }

    // MARK: - Keystroke / text injection

    private static func postCombo(_ combo: KeyCombo) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: combo.keyCode, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: combo.keyCode, keyDown: false)
        down?.flags = combo.modifiers
        up?.flags = combo.modifiers
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    private static func typeText(_ text: String) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let utf16 = Array(text.utf16)
        guard
            let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
        else { return }
        utf16.withUnsafeBufferPointer { buffer in
            down.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: buffer.baseAddress)
            up.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: buffer.baseAddress)
        }
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
