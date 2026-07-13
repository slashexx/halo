import Foundation

/// What a slot does when chosen.
enum ItemKind: String, Codable {
    case action    // runs `action`
    case clipboard // opens the clipboard history sub-menu
}

/// A single slot in a radial menu. `Codable` so wheels persist and (later) ship
/// as shareable presets.
struct MenuItem: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var icon: ItemIcon
    var action: HaloAction?
    var kind: ItemKind

    init(id: UUID = UUID(), title: String, icon: ItemIcon,
         action: HaloAction? = nil, kind: ItemKind = .action) {
        self.id = id
        self.title = title
        self.icon = icon
        self.action = action
        self.kind = kind
    }

    // Custom Codable so older saved files (without `kind`) still decode.
    enum CodingKeys: String, CodingKey { case id, title, icon, action, kind }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        icon = try c.decode(ItemIcon.self, forKey: .icon)
        action = try c.decodeIfPresent(HaloAction.self, forKey: .action)
        kind = try c.decodeIfPresent(ItemKind.self, forKey: .kind) ?? .action
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(icon, forKey: .icon)
        try c.encodeIfPresent(action, forKey: .action)
        try c.encode(kind, forKey: .kind)
    }

    // Identity-based equality/hashing so ForEach stays stable as items are edited.
    static func == (lhs: MenuItem, rhs: MenuItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
