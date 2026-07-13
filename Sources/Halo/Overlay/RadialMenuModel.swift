import SwiftUI

/// Observable state backing the radial overlay: a fixed set of slots (each
/// either a `MenuItem` or empty) and which slot the cursor points at.
@MainActor
final class RadialMenuModel: ObservableObject {
    static let slotCount = 8

    @Published var slots: [MenuItem?]
    @Published var highlightedIndex: Int?

    init(slots: [MenuItem?]? = nil) {
        self.slots = slots ?? MenuStore.load() ?? RadialMenuModel.defaultSlots
    }

    var slotCount: Int { slots.count }

    func reset() {
        highlightedIndex = nil
    }

    func setSlot(_ index: Int, to item: MenuItem?) {
        guard slots.indices.contains(index) else { return }
        slots[index] = item
        MenuStore.save(slots)
    }

    // MARK: - Defaults

    /// First-run wheel: a few useful items plus two empty "+" slots to invite
    /// customization. Persisted the moment the user changes anything.
    static var defaultSlots: [MenuItem?] {
        var result: [MenuItem?] = [
            MenuItem(title: "Finder", icon: .symbol("folder"),
                     action: .launchApp(name: "Finder")),
            MenuItem(title: "Halo repo", icon: .symbol("safari"),
                     action: .openURL("https://github.com/slashexx/halo")),
            MenuItem(title: "Terminal", icon: .symbol("terminal"),
                     action: .launchApp(name: "Terminal")),
            MenuItem(title: "Snippet", icon: .symbol("text.badge.plus"),
                     action: .insertText("Everything at your cursor. — Halo")),
            MenuItem(title: "Screenshot", icon: .symbol("camera.viewfinder"),
                     action: .keyboardShortcut(KeyCombo(keyCode: 21,
                                                        modifiers: [.maskCommand, .maskShift]))),
            MenuItem(title: "Music", icon: .symbol("music.note"),
                     action: .launchApp(name: "Music")),
        ]
        while result.count < slotCount { result.append(nil) }
        return result
    }
}
