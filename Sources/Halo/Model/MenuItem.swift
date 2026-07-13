import Foundation

/// A single slot in a radial menu. `Codable` so wheels persist and (later) ship
/// as shareable presets. Phase 3+ lets a slot open a nested sub-menu.
struct MenuItem: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var icon: ItemIcon
    var action: HaloAction?

    init(id: UUID = UUID(), title: String, icon: ItemIcon, action: HaloAction? = nil) {
        self.id = id
        self.title = title
        self.icon = icon
        self.action = action
    }

    // Identity-based equality/hashing so ForEach stays stable as items are edited.
    static func == (lhs: MenuItem, rhs: MenuItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
