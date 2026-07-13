import SwiftUI

/// Observable state backing the radial overlay: the items to show and which one
/// the cursor is currently pointing at.
@MainActor
final class RadialMenuModel: ObservableObject {
    @Published var items: [MenuItem]
    @Published var highlightedIndex: Int?

    init(items: [MenuItem] = RadialMenuModel.demo) {
        self.items = items
    }

    func reset() {
        highlightedIndex = nil
    }

    /// Placeholder menu used until Phase 3 loads real, user-defined menus.
    /// Each item now runs a real action so the engine can be exercised end-to-end.
    static let demo: [MenuItem] = [
        MenuItem(title: "Finder", systemImage: "folder",
                 action: .launchApp(name: "Finder")),
        MenuItem(title: "Halo repo", systemImage: "safari",
                 action: .openURL("https://github.com/slashexx/halo")),
        MenuItem(title: "Terminal", systemImage: "terminal",
                 action: .launchApp(name: "Terminal")),
        MenuItem(title: "Snippet", systemImage: "text.badge.plus",
                 action: .insertText("Everything at your cursor. — Halo")),
        MenuItem(title: "Screenshot", systemImage: "camera.viewfinder",
                 action: .keyboardShortcut(KeyCombo(keyCode: 21, modifiers: [.maskCommand, .maskShift]))),
        MenuItem(title: "Notify", systemImage: "bell",
                 action: .runAppleScript(#"display notification "Hello from Halo" with title "Halo""#)),
        MenuItem(title: "Music", systemImage: "music.note",
                 action: .launchApp(name: "Music")),
        MenuItem(title: "Log date", systemImage: "curlybraces",
                 action: .runShell("date >> /tmp/halo-demo.log")),
    ]
}
