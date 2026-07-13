import Foundation

/// How a menu item is drawn: an SF Symbol, or a real app icon loaded from disk.
enum ItemIcon: Codable, Equatable {
    case symbol(String)          // SF Symbol name
    case appIcon(path: String)   // path to a .app bundle; icon loaded at render time
}
