import SwiftUI

/// Observable state backing the overlay: the slots (the ring), whether the
/// clipboard side-panel is open, and the two independent highlights (ring slot
/// vs. clipboard row).
@MainActor
final class RadialMenuModel: ObservableObject {
    static let slotCount = 8

    @Published var slots: [MenuItem?]
    @Published var clipboardOpen = false
    @Published var hubFocused = false           // cursor is over the center hub
    @Published var highlightedIndex: Int?       // ring slot under the cursor
    @Published var highlightedClipIndex: Int?   // clipboard row under the cursor

    /// Snapshot taken when the panel opens, so the list is stable while browsed.
    private(set) var clipboardEntries: [ClipboardEntry] = []

    init(slots: [MenuItem?]? = nil) {
        self.slots = slots ?? MenuStore.load() ?? RadialMenuModel.defaultSlots
    }

    var slotCountValue: Int { slots.count }

    func item(at index: Int) -> MenuItem? {
        slots.indices.contains(index) ? slots[index] : nil
    }

    func isClipboardSlot(_ index: Int) -> Bool {
        item(at: index)?.kind == .clipboard
    }

    // MARK: - Navigation

    func reset() {
        clipboardOpen = false
        hubFocused = false
        highlightedIndex = nil
        highlightedClipIndex = nil
    }

    func openClipboard() {
        clipboardEntries = Array(ClipboardMonitor.shared.entries.prefix(ClipboardMonitor.shared.maxEntries))
        clipboardOpen = true
        highlightedClipIndex = nil
    }

    func closeClipboard() {
        clipboardOpen = false
        highlightedClipIndex = nil
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
            MenuItem(title: "Snippet", icon: .symbol("text.badge.plus"),
                     action: .insertText("Everything at your cursor. — Halo")),
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
