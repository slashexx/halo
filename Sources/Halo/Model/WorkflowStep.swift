import Foundation

/// The action types a workflow step can be, for the editor's type picker.
enum StepKind: String, CaseIterable, Identifiable {
    case launchApp, openURL, keyboardShortcut, moveWindow, runAppleScript, runShell, insertText

    var id: String { rawValue }

    var title: String {
        switch self {
        case .launchApp: "Launch App"
        case .openURL: "Open URL / File"
        case .keyboardShortcut: "Keyboard Shortcut"
        case .moveWindow: "Move Window"
        case .runAppleScript: "Run AppleScript"
        case .runShell: "Run Shell"
        case .insertText: "Insert Text"
        }
    }

    var placeholder: String {
        switch self {
        case .launchApp: "App name, e.g. Safari"
        case .openURL: "https://… or /path/to/file"
        case .runAppleScript: "AppleScript source"
        case .runShell: "Shell command"
        case .insertText: "Text to type"
        case .keyboardShortcut, .moveWindow: ""
        }
    }
}

/// A mutable, identifiable step used while editing a workflow. Converts to/from
/// the immutable `HaloAction` that actually runs and persists.
struct WorkflowStep: Identifiable, Equatable {
    let id: UUID
    var kind: StepKind
    var text: String
    var combo: KeyCombo?
    var shortcutDisplay: String  // UI-only label for a recorded combo
    var windowPosition: WindowPosition

    init(id: UUID = UUID(), kind: StepKind = .launchApp, text: String = "",
         combo: KeyCombo? = nil, shortcutDisplay: String = "",
         windowPosition: WindowPosition = .leftHalf) {
        self.id = id
        self.kind = kind
        self.text = text
        self.combo = combo
        self.shortcutDisplay = shortcutDisplay
        self.windowPosition = windowPosition
    }

    init(action: HaloAction) {
        switch action {
        case .launchApp(let name): self.init(kind: .launchApp, text: name)
        case .openURL(let url): self.init(kind: .openURL, text: url)
        case .keyboardShortcut(let combo): self.init(kind: .keyboardShortcut, combo: combo)
        case .moveWindow(let position): self.init(kind: .moveWindow, windowPosition: position)
        case .runAppleScript(let src): self.init(kind: .runAppleScript, text: src)
        case .runShell(let cmd): self.init(kind: .runShell, text: cmd)
        case .insertText(let text): self.init(kind: .insertText, text: text)
        case .chain: self.init() // nested chains aren't edited inline
        }
    }

    var action: HaloAction {
        switch kind {
        case .launchApp: .launchApp(name: text)
        case .openURL: .openURL(text)
        case .keyboardShortcut: .keyboardShortcut(combo ?? KeyCombo(keyCode: 0, modifiers: []))
        case .moveWindow: .moveWindow(windowPosition)
        case .runAppleScript: .runAppleScript(text)
        case .runShell: .runShell(text)
        case .insertText: .insertText(text)
        }
    }
}
