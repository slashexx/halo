import AppKit
import QuickLookThumbnailing
import SwiftUI

/// Preview for a clipboard entry inside a ring circle: text snippet on glass,
/// an image thumbnail, or a QuickLook thumbnail for files (images & videos),
/// falling back to the file-type icon.
struct ClipThumbnailView: View {
    let entry: ClipboardEntry
    let size: CGFloat

    @State private var fileThumbnail: NSImage?

    var body: some View {
        content
            .frame(width: size, height: size)
            .clipShape(.circle)
            .task(id: entry.id) { await loadFileThumbnail() }
    }

    @ViewBuilder
    private var content: some View {
        switch entry.content {
        case .text(let string):
            Text(string.trimmingCharacters(in: .whitespacesAndNewlines).prefix(28))
                .font(.system(size: 9, weight: .medium))
                .lineLimit(3)
                .multilineTextAlignment(.center)
                .padding(6)
                .frame(width: size, height: size)
                .foregroundStyle(.primary)
                .glassEffect(.regular, in: .circle)

        case .image(let image):
            Image(nsImage: image).resizable().scaledToFill()

        case .file(let url):
            if let fileThumbnail {
                Image(nsImage: fileThumbnail).resizable().scaledToFill()
            } else {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable().scaledToFit().padding(10)
                    .glassEffect(.regular, in: .circle)
            }
        }
    }

    private func loadFileThumbnail() async {
        guard case .file(let url) = entry.content else { return }
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: size * 2, height: size * 2),
            scale: 2,
            representationTypes: .thumbnail
        )
        if let rep = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) {
            fileThumbnail = rep.nsImage
        }
    }
}
