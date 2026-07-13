import CoreGraphics

/// A key + modifier combination to simulate, e.g. ⌘⇧4 for screenshot-region.
struct KeyCombo: Equatable {
    var keyCode: CGKeyCode
    var modifiers: CGEventFlags
}

/// One executable action — the building block a menu item runs when chosen.
///
/// Phase 2 implements the five core blocks below. Later phases add window
/// management, system actions, app switcher, and chaining, and make this
/// `Codable` for persistence + shareable presets.
enum HaloAction: Equatable {
    case launchApp(name: String)          // app name or bundle id, via `open -a`
    case openURL(String)                  // https URL, custom scheme, file, or folder
    case keyboardShortcut(KeyCombo)       // simulate a key combo
    case runAppleScript(String)           // execute AppleScript source
    case runShell(String)                 // run a shell command
    case insertText(String)               // type text into the focused field

    /// Whether executing requires Accessibility (keystroke / text injection).
    var needsAccessibility: Bool {
        switch self {
        case .keyboardShortcut, .insertText: return true
        default: return false
        }
    }

    @MainActor
    func execute() {
        ActionRunner.run(self)
    }
}
