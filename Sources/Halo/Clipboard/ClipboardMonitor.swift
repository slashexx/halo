import AppKit

/// Watches the system pasteboard and keeps the most recent copies (default 10),
/// newest first. Text, images, and files (incl. videos) are captured. Selecting
/// an entry writes it back to the pasteboard as the current clipboard.
@MainActor
final class ClipboardMonitor: ObservableObject {
    static let shared = ClipboardMonitor()

    @Published private(set) var entries: [ClipboardEntry] = []

    let maxEntries = 10
    private var lastChangeCount = NSPasteboard.general.changeCount
    private var timer: Timer?

    private init() {}

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 0.6, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func poll() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        capture(from: pasteboard)
    }

    private func capture(from pasteboard: NSPasteboard) {
        // Files (images, videos, anything) first, so a copied file keeps its URL.
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL],
           let url = urls.first {
            prepend(.file(url))
            return
        }
        if let image = NSImage(pasteboard: pasteboard) {
            prepend(.image(image))
            return
        }
        if let string = pasteboard.string(forType: .string),
           !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            prepend(.text(string))
        }
    }

    private func prepend(_ content: ClipboardEntry.Content) {
        entries.insert(ClipboardEntry(content: content, date: Date()), at: 0)
        if entries.count > maxEntries {
            entries.removeLast(entries.count - maxEntries)
        }
    }

    /// Makes an entry the current clipboard content.
    func makeCurrent(_ entry: ClipboardEntry) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        switch entry.content {
        case .text(let string): pasteboard.setString(string, forType: .string)
        case .image(let image): pasteboard.writeObjects([image])
        case .file(let url): pasteboard.writeObjects([url as NSURL])
        }
        // Don't re-capture our own write as a new copy.
        lastChangeCount = pasteboard.changeCount
    }

    func clear() {
        entries.removeAll()
    }
}
