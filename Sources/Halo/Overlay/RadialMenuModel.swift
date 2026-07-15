import SwiftUI

/// Observable state backing the overlay. Two navigation levels: the root ring
/// of slots, and a nested clipboard ring. At root the center hub flips to the
/// media player; inside the clipboard ring the center acts as "‹ Back".
@MainActor
final class RadialMenuModel: ObservableObject {
    static let slotCount = 8

    enum Level: Equatable { case root, clipboard }

    @Published var slots: [MenuItem?]
    @Published var level: Level = .root
    @Published var hubFocused = false        // cursor over the center hub (root → media flip)
    @Published var highlightedIndex: Int?    // index into the current level's nodes

    private(set) var clipboardEntries: [ClipboardEntry] = []

    init(slots: [MenuItem?]? = nil) {
        self.slots = slots ?? MenuStore.load() ?? RadialMenuModel.defaultSlots
    }

    /// Number of nodes shown on the ring at the current level.
    var nodeCount: Int {
        level == .root ? slots.count : clipboardEntries.count
    }

    func item(at index: Int) -> MenuItem? {
        slots.indices.contains(index) ? slots[index] : nil
    }

    func isClipboardSlot(_ index: Int) -> Bool {
        level == .root && item(at: index)?.kind == .clipboard
    }

    // MARK: - Navigation

    func reset() {
        level = .root
        hubFocused = false
        highlightedIndex = nil
    }

    func openClipboard() {
        clipboardEntries = Array(ClipboardMonitor.shared.entries.prefix(ClipboardMonitor.shared.maxEntries))
        level = .clipboard
        hubFocused = false
        highlightedIndex = nil
    }

    func back() {
        level = .root
        highlightedIndex = nil
    }

    // MARK: - Mutation

    func setSlot(_ index: Int, to item: MenuItem?) {
        guard slots.indices.contains(index) else { return }
        slots[index] = item
        MenuStore.save(slots)
    }

    // MARK: - Defaults

    /// First-run wheel: useful items incl. the Clipboard, plus an empty "+" slot.
    static var defaultSlots: [MenuItem?] {
        var result: [MenuItem?] = [
            MenuItem(title: "Finder", icon: .symbol("folder"),
                     action: .launchApp(name: "Finder")),
            MenuItem(title: "Clipboard", icon: .symbol("doc.on.clipboard"),
                     kind: .clipboard),
            MenuItem(title: "Terminal", icon: .symbol("terminal"),
                     action: .launchApp(name: "Terminal")),
            MenuItem(title: "Screenshot", icon: .symbol("camera.viewfinder"),
                     action: .keyboardShortcut(KeyCombo(keyCode: 21,
                                                        modifiers: [.maskCommand, .maskShift]))),
            MenuItem(title: "Music", icon: .symbol("music.note"),
                     action: .launchApp(name: "Music")),
            MenuItem(title: "Halo repo", icon: .symbol("safari"),
                     action: .openURL("https://github.com/slashexx/halo")),
        ]
        while result.count < slotCount { result.append(nil) }
        return result
    }
}
