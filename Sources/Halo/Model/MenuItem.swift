import Foundation

/// A single slot in a radial menu. In Phase 1 this only carries display data;
/// Phase 2 attaches an executable action and Phase 3 makes it `Codable` and
/// allows a slot to open a nested sub-menu.
struct MenuItem: Identifiable, Hashable {
    let id: UUID
    var title: String
    var systemImage: String

    init(id: UUID = UUID(), title: String, systemImage: String) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
    }
}
