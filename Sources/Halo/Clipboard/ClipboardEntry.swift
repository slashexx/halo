import AppKit

/// One remembered clipboard item. Text, an image, or a file (image/video/other).
struct ClipboardEntry: Identifiable {
    enum Content {
        case text(String)
        case image(NSImage)
        case file(URL)
    }

    let id = UUID()
    let content: Content
    let date: Date

    /// Short label for the hub / accessibility.
    var summary: String {
        switch content {
        case .text(let string):
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return String(trimmed.prefix(40))
        case .image:
            return "Image"
        case .file(let url):
            return url.lastPathComponent
        }
    }
}
