import CoreGraphics

/// A key + modifier combination to simulate, e.g. ⌘⇧4 for screenshot-region.
struct KeyCombo: Equatable, Codable {
    var keyCode: CGKeyCode
    var modifiers: CGEventFlags

    init(keyCode: CGKeyCode, modifiers: CGEventFlags) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    // CGEventFlags isn't Codable, so persist its raw value.
    private enum CodingKeys: String, CodingKey { case keyCode, modifiers }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        keyCode = try container.decode(CGKeyCode.self, forKey: .keyCode)
        modifiers = CGEventFlags(rawValue: try container.decode(UInt64.self, forKey: .modifiers))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(keyCode, forKey: .keyCode)
        try container.encode(modifiers.rawValue, forKey: .modifiers)
    }
}

/// One executable action — the building block a menu item runs when chosen.
///
/// Phase 2 implements the five core blocks below. Later phases add window
/// management, system actions, app switcher, and chaining (workflows).
enum HaloAction: Equatable, Codable {
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
