import Foundation

/// A thing drawn around the ring at the current navigation level: either a
/// top-level slot (which may be empty) or a clipboard-history entry.
enum WheelNode: Identifiable {
    case slot(index: Int, item: MenuItem?)
    case clip(ClipboardEntry)

    var id: String {
        switch self {
        case .slot(let index, _): "slot-\(index)"
        case .clip(let entry): "clip-\(entry.id.uuidString)"
        }
    }
}
