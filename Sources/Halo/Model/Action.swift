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

/// Where to place the frontmost window.
enum WindowPosition: String, Codable, CaseIterable, Identifiable {
    case leftHalf, rightHalf, topHalf, bottomHalf, maximize, center

    var id: String { rawValue }
    var title: String {
        switch self {
        case .leftHalf: "Left Half"
        case .rightHalf: "Right Half"
        case .topHalf: "Top Half"
        case .bottomHalf: "Bottom Half"
        case .maximize: "Maximize"
        case .center: "Center"
        }
    }
}

/// One executable action — the building block a menu item runs when chosen.
enum HaloAction: Equatable, Codable {
    case launchApp(name: String)          // app name or bundle id, via `open -a`
    case openURL(String)                  // https URL, custom scheme, file, or folder
    case keyboardShortcut(KeyCombo)       // simulate a key combo
    case runAppleScript(String)           // execute AppleScript source
    case runShell(String)                 // run a shell command
    case insertText(String)               // type text into the focused field
    case moveWindow(WindowPosition)       // reposition the frontmost window
    indirect case chain([HaloAction])     // a workflow: run steps in sequence

    /// Whether executing requires Accessibility (keystroke/text injection, or
    /// moving another app's window).
    var needsAccessibility: Bool {
        switch self {
        case .keyboardShortcut, .insertText, .moveWindow: return true
        case .chain(let steps): return steps.contains { $0.needsAccessibility }
        default: return false
        }
    }

    /// Whether the action is worth running (skips empty text/app/script steps).
    var isMeaningful: Bool {
        func filled(_ s: String) -> Bool { !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        switch self {
        case .launchApp(let n): return filled(n)
        case .openURL(let s): return filled(s)
        case .runAppleScript(let s): return filled(s)
        case .runShell(let s): return filled(s)
        case .insertText(let s): return !s.isEmpty
        case .keyboardShortcut(let c): return c.keyCode != 0 || !c.modifiers.isEmpty
        case .moveWindow: return true
        case .chain(let steps): return steps.contains { $0.isMeaningful }
        }
    }

    @MainActor
    func execute() {
        ActionRunner.run(self)
    }
}
