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
        case .moveWindow(let position): WindowManager.move(position)
        case .chain(let steps): runChain(steps, from: 0)
        }
    }

    /// Runs workflow steps in order, pausing between them so each takes effect
    /// before the next. Launches/opens get a longer pause so a following step
    /// (e.g. Move Window) doesn't fire before the app's window exists.
    private static func runChain(_ steps: [HaloAction], from index: Int) {
        guard index < steps.count else { return }
        run(steps[index])
        let next = index + 1
        guard next < steps.count else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delayAfter(steps[index])) {
            runChain(steps, from: next)
        }
    }

    private static func delayAfter(_ action: HaloAction) -> TimeInterval {
        switch action {
        case .launchApp, .openURL: return 1.1 // let the app / window come up
        default: return 0.4
        }
    }

    // MARK: - Launch / open

    private static func launchApp(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { NSLog("Halo: 'Launch App' step is empty — skipped."); return }
        runProcess("/usr/bin/open", ["-a", trimmed], label: "launch \(trimmed)")
    }

    private static func openTarget(_ target: String) {
        let trimmed = target.trimmingCharacters(in: .whitespacesAndNewlines)
        // Never fall through to URL(fileURLWithPath: "") — that opens "/" (the
        // "Macintosh HD" Finder window). Empty / unknown targets no-op + log.
        guard !trimmed.isEmpty else { NSLog("Halo: 'Open URL/File' step is empty — skipped."); return }

        if let url = URL(string: trimmed), let scheme = url.scheme, !scheme.isEmpty {
            NSWorkspace.shared.open(url)
            return
        }
        let expanded = (trimmed as NSString).expandingTildeInPath
        if FileManager.default.fileExists(atPath: expanded) {
            NSWorkspace.shared.open(URL(fileURLWithPath: expanded))
        } else {
            NSLog("Halo: 'Open URL/File' — '%@' is not a URL or an existing path; skipped.", trimmed)
        }
    }

    // MARK: - Scripts

    private static func runAppleScript(_ source: String) {
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error {
            NSLog("Halo: AppleScript error: %@", error)
        }
    }

    private static func runShell(_ command: String) {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // Login shell + augmented PATH so Homebrew / user CLIs (e.g. `claude`)
        // resolve; run from home; capture output so failures are visible.
        runProcess("/bin/zsh", ["-lc", trimmed], label: "shell",
                   augmentPath: true, cwd: NSHomeDirectory())
    }

    private static func runProcess(
        _ launchPath: String, _ arguments: [String], label: String,
        augmentPath: Bool = false, cwd: String? = nil
    ) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        if let cwd { process.currentDirectoryURL = URL(fileURLWithPath: cwd) }
        if augmentPath {
            var env = ProcessInfo.processInfo.environment
            let extras = "/opt/homebrew/bin:/usr/local/bin:\(NSHomeDirectory())/.local/bin"
            env["PATH"] = extras + ":" + (env["PATH"] ?? "/usr/bin:/bin")
            process.environment = env
        }

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        process.terminationHandler = { proc in
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard proc.terminationStatus != 0 else { return }
            let out = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            NSLog("Halo: %@ failed (exit %d)%@", label, proc.terminationStatus,
                  out.isEmpty ? "" : ": " + out)
        }

        do {
            try process.run()
        } catch {
            NSLog("Halo: %@ could not start: %@", label, error.localizedDescription)
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
