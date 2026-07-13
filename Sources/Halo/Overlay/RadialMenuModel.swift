import SwiftUI

/// Observable state backing the overlay: the slots, the current navigation level
/// (root or a clipboard sub-menu), and which node the cursor points at.
@MainActor
final class RadialMenuModel: ObservableObject {
    static let slotCount = 8

    enum Level: Equatable { case root, clipboard }

    @Published var slots: [MenuItem?]
    @Published var level: Level = .root
    @Published var highlightedIndex: Int?

    /// Snapshot of clipboard entries taken when the sub-menu is opened, so the
    /// ring is stable while the user navigates it.
    private(set) var clipboardEntries: [ClipboardEntry] = []

    init(slots: [MenuItem?]? = nil) {
        self.slots = slots ?? MenuStore.load() ?? RadialMenuModel.defaultSlots
    }

    // MARK: - Nodes for the current level

    var nodes: [WheelNode] {
        switch level {
        case .root:
            slots.enumerated().map { WheelNode.slot(index: $0.offset, item: $0.element) }
        case .clipboard:
            clipboardEntries.map { WheelNode.clip($0) }
        }
    }

    var nodeCount: Int { nodes.count }

    func node(at index: Int) -> WheelNode? {
        nodes.indices.contains(index) ? nodes[index] : nil
    }

    func isClipboardSlot(_ index: Int) -> Bool {
        if case .slot(_, let item)? = node(at: index) { return item?.kind == .clipboard }
        return false
    }

    // MARK: - Navigation

    func reset() {
        level = .root
        highlightedIndex = nil
    }

    func enterClipboard() {
        clipboardEntries = Array(ClipboardMonitor.shared.entries.prefix(ClipboardMonitor.shared.maxEntries))
        level = .clipboard
        highlightedIndex = nil
    }

    func popToRoot() {
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
