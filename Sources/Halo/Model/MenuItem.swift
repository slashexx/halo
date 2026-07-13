import Foundation

/// A single slot in a radial menu. Phase 3 makes it `Codable` and lets a slot
/// open a nested sub-menu instead of running an action.
struct MenuItem: Identifiable, Hashable {
    let id: UUID
    var title: String
    var systemImage: String
    var action: HaloAction?

    init(id: UUID = UUID(), title: String, systemImage: String, action: HaloAction? = nil) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    // Identity-based equality/hashing so `HaloAction` needn't be Hashable and
    // ForEach stays stable while an item's action is edited.
    static func == (lhs: MenuItem, rhs: MenuItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
