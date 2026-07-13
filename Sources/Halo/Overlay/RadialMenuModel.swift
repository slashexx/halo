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
    static let demo: [MenuItem] = [
        MenuItem(title: "Finder", systemImage: "folder"),
        MenuItem(title: "Safari", systemImage: "safari"),
        MenuItem(title: "Terminal", systemImage: "terminal"),
        MenuItem(title: "Snippet", systemImage: "text.badge.plus"),
        MenuItem(title: "Screenshot", systemImage: "camera.viewfinder"),
        MenuItem(title: "Focus", systemImage: "moon.fill"),
        MenuItem(title: "Music", systemImage: "music.note"),
        MenuItem(title: "Script", systemImage: "curlybraces"),
    ]
}
