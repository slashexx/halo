import AppKit
import SwiftUI

/// The clipboard sub-menu, rendered as an ordered vertical list (a ring can't
/// convey recency). Newest first, numbered, with previews. Hover highlights a
/// row; release ⌥Tab / click sets it as the current clipboard.
struct ClipboardListView: View {
    @ObservedObject var model: RadialMenuModel
    var onActivate: (Int) -> Void
    var onBack: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            header

            if model.clipboardEntries.isEmpty {
                emptyState
            } else {
                VStack(spacing: 4) {
                    ForEach(Array(model.clipboardEntries.enumerated()), id: \.element.id) { index, entry in
                        row(index: index, entry: entry, highlighted: model.highlightedClipIndex == index)
                            .contentShape(RoundedRectangle(cornerRadius: 12))
                            .onHover { if $0 { model.highlightedClipIndex = index } }
                            .onTapGesture { onActivate(index) }
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 380)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 26))
        .shadow(color: .black.opacity(0.22), radius: 20, y: 8)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)

            Text("Clipboard")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
            Spacer()
            Text("^[\(model.clipboardEntries.count) item](inflect: true)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "doc.on.clipboard").font(.system(size: 26)).foregroundStyle(.secondary)
            Text("No recent copies").font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
    }

    private func row(index: Int, entry: ClipboardEntry, highlighted: Bool) -> some View {
        HStack(spacing: 10) {
            Text("\(index + 1)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(index == 0 ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                .frame(width: 20, height: 20)
                .background(index == 0 ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary), in: .circle)

            thumbnail(entry)
                .frame(width: 30, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 1) {
                Text(primaryLabel(entry)).font(.system(size: 13)).lineLimit(1)
                Text(secondaryLabel(entry, index: index))
                    .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 4)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(highlighted ? AnyShapeStyle(.tint.opacity(0.22)) : AnyShapeStyle(.clear),
                    in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(highlighted ? 0.35 : 0), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func thumbnail(_ entry: ClipboardEntry) -> some View {
        switch entry.content {
        case .text:
            Image(systemName: "doc.plaintext")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 7))
        case .image, .file:
            ClipThumbnailView(entry: entry, size: 30)
        }
    }

    private func primaryLabel(_ entry: ClipboardEntry) -> String {
        switch entry.content {
        case .text(let string):
            string.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\n", with: " ")
        case .image:
            "Image"
        case .file(let url):
            url.lastPathComponent
        }
    }

    private func secondaryLabel(_ entry: ClipboardEntry, index: Int) -> String {
        let kind: String
        switch entry.content {
        case .text: kind = "Text"
        case .image: kind = "Image"
        case .file: kind = "File"
        }
        return index == 0 ? "\(kind) · Latest" : kind
    }
}
