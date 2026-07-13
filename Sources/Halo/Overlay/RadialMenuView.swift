import AppKit
import SwiftUI

/// The radial menu. Root level: a ring of slots with a center hub that flips to
/// the media player. Clipboard level: a nested ring of numbered recent copies
/// with the center acting as "‹ Back".
struct RadialMenuView: View {
    @ObservedObject var model: RadialMenuModel
    @ObservedObject var media: MediaHubModel

    var onActivate: (Int) -> Void   // slot (root) or clip (clipboard), by level
    var onEdit: (Int) -> Void
    var onEditWorkflow: (Int) -> Void
    var onRename: (Int) -> Void
    var onClear: (Int) -> Void
    var onBack: () -> Void
    var onDismiss: () -> Void

    @State private var appeared: Bool

    private let hubSize: CGFloat = 160   // large enough for the media player
    private var hubRadius: CGFloat { hubSize / 2 }

    init(
        model: RadialMenuModel,
        media: MediaHubModel = MediaHubModel(),
        startVisible: Bool = false,
        onActivate: @escaping (Int) -> Void,
        onEdit: @escaping (Int) -> Void = { _ in },
        onEditWorkflow: @escaping (Int) -> Void = { _ in },
        onRename: @escaping (Int) -> Void = { _ in },
        onClear: @escaping (Int) -> Void = { _ in },
        onBack: @escaping () -> Void = {},
        onDismiss: @escaping () -> Void = {}
    ) {
        self._model = ObservedObject(wrappedValue: model)
        self._media = ObservedObject(wrappedValue: media)
        self.onActivate = onActivate
        self.onEdit = onEdit
        self.onEditWorkflow = onEditWorkflow
        self.onRename = onRename
        self.onClear = onClear
        self.onBack = onBack
        self.onDismiss = onDismiss
        self._appeared = State(initialValue: startVisible)
    }

    // Ring pulled in to just clear the 160pt hub, with slightly larger circles,
    // so items sit close together (packed) without shrinking. Clipboard ring is
    // a touch wider to fit up to 10 numbered items.
    private var ringRadius: CGFloat { model.level == .clipboard ? 150 : 126 }
    private var itemSize: CGFloat { model.level == .clipboard ? 52 : 66 }

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let count = model.nodeCount

            ZStack {
                hub.position(center)

                ForEach(0..<count, id: \.self) { index in
                    nodeView(index: index, isHighlighted: model.highlightedIndex == index)
                        .position(position(for: index, count: count, center: center))
                }
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                if case .active(let location) = phase {
                    updateHighlight(at: location, center: center, count: count)
                }
            }
            .onTapGesture { handleTap() }
            .task(id: dwellKey) {
                guard model.level == .root, let index = model.highlightedIndex,
                      model.isClipboardSlot(index) else { return }
                try? await Task.sleep(for: .seconds(AppSettings.clipboardHoverDelay))
                if model.highlightedIndex == index, model.level == .root {
                    model.openClipboard()
                }
            }
            .task(id: model.hubFocused) {
                guard model.hubFocused else { return }
                media.refresh()
                while !Task.isCancelled && model.hubFocused {
                    try? await Task.sleep(for: .seconds(1.2))
                    if model.hubFocused { media.refresh() }
                }
            }
        }
        .scaleEffect(appeared ? 1 : 0.92)
        .opacity(appeared ? 1 : 0)
        .animation(.smooth(duration: 0.24), value: appeared)
        .animation(.smooth(duration: 0.18), value: model.highlightedIndex)
        .animation(.smooth(duration: 0.28), value: model.level)
        .animation(.smooth(duration: 0.38), value: model.hubFocused)
        .onAppear { appeared = true }
    }

    private var dwellKey: String { "\(model.level == .root ? "r" : "c")-\(model.highlightedIndex ?? -1)" }

    private func handleTap() {
        if model.level == .clipboard {
            if let index = model.highlightedIndex { onActivate(index) } else { onBack() }
        } else if model.hubFocused {
            // Center flipped to the media player — its own buttons handle taps.
        } else if let index = model.highlightedIndex {
            onActivate(index)
        } else {
            onDismiss()
        }
    }

    // MARK: - Hub

    private var hub: some View {
        ZStack {
            Circle().fill(.clear).glassEffect(.regular, in: .circle)

            if model.level == .clipboard {
                clipboardHub
            } else {
                ZStack {
                    rootHubFront.opacity(model.hubFocused ? 0 : 1)
                    MediaPlayerFace(media: media, size: hubSize)
                        .opacity(model.hubFocused ? 1 : 0)
                        .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                }
                .rotation3DEffect(.degrees(model.hubFocused ? 180 : 0),
                                  axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            }
        }
        .frame(width: hubSize, height: hubSize)
        .clipShape(.circle)
        .shadow(color: .black.opacity(0.18), radius: 12, y: 3)
    }

    @ViewBuilder
    private var rootHubFront: some View {
        if let index = model.highlightedIndex, let item = model.item(at: index) {
            Text(item.title).modifier(HubLabel())
        } else {
            VStack(spacing: 4) {
                Image(systemName: "play.circle").font(.system(size: 24, weight: .medium))
                Text("Media").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
        }
    }

    @ViewBuilder
    private var clipboardHub: some View {
        if let index = model.highlightedIndex, model.clipboardEntries.indices.contains(index) {
            VStack(spacing: 2) {
                Text("\(index + 1)").font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.tint)
                Text(model.clipboardEntries[index].summary).modifier(HubLabel())
            }
        } else {
            VStack(spacing: 3) {
                Image(systemName: "chevron.backward").font(.system(size: 16, weight: .semibold))
                Text("Back").font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(.primary)
        }
    }

    // MARK: - Nodes

    @ViewBuilder
    private func nodeView(index: Int, isHighlighted: Bool) -> some View {
        if model.level == .clipboard {
            clipNode(index: index, isHighlighted: isHighlighted)
        } else {
            slotNode(index: index, isHighlighted: isHighlighted)
        }
    }

    @ViewBuilder
    private func slotNode(index: Int, isHighlighted: Bool) -> some View {
        if let item = model.item(at: index) {
            iconView(item.icon)
                .frame(width: itemSize, height: itemSize)
                .glassEffect(.regular, in: .circle)
                .overlay(rim(isHighlighted))
                .modifier(RingItem(isHighlighted: isHighlighted))
                .contextMenu {
                    if item.kind == .action, case .chain? = item.action {
                        Button("Edit workflow…") { onEditWorkflow(index) }
                    }
                    Button("Rename…") { onRename(index) }
                    Button("Replace…") { onEdit(index) }
                    Button("Remove", role: .destructive) { onClear(index) }
                }
        } else {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: itemSize, height: itemSize)
                .glassEffect(.regular, in: .circle)
                .overlay(Circle().strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                    .foregroundStyle(.white.opacity(isHighlighted ? 0.45 : 0.18)))
                .modifier(RingItem(isHighlighted: isHighlighted))
                .contextMenu { Button("Add…") { onEdit(index) } }
        }
    }

    private func clipNode(index: Int, isHighlighted: Bool) -> some View {
        ClipThumbnailView(entry: model.clipboardEntries[index], size: itemSize)
            .overlay(rim(isHighlighted))
            .overlay(alignment: .topLeading) {
                Text("\(index + 1)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 17, height: 17)
                    .background(index == 0 ? AnyShapeStyle(.tint) : AnyShapeStyle(.black.opacity(0.6)),
                                in: .circle)
                    .offset(x: -3, y: -3)
            }
            .modifier(RingItem(isHighlighted: isHighlighted))
    }

    private func rim(_ isHighlighted: Bool) -> some View {
        Circle().strokeBorder(.white.opacity(isHighlighted ? 0.55 : 0.10),
                              lineWidth: isHighlighted ? 1.5 : 0.75)
    }

    @ViewBuilder
    private func iconView(_ icon: ItemIcon) -> some View {
        switch icon {
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: 24, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.primary)
        case .appIcon(let path):
            Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                .resizable().frame(width: 34, height: 34)
        }
    }

    // MARK: - Geometry & selection

    private func angleDegrees(for index: Int, count: Int) -> Double {
        let step = 360.0 / Double(max(count, 1))
        return -90.0 + step * Double(index)
    }

    private func position(for index: Int, count: Int, center: CGPoint) -> CGPoint {
        let radians = angleDegrees(for: index, count: count) * .pi / 180.0
        return CGPoint(x: center.x + cos(radians) * ringRadius,
                       y: center.y + sin(radians) * ringRadius)
    }

    private func updateHighlight(at location: CGPoint, center: CGPoint, count: Int) {
        let dx = location.x - center.x
        let dy = location.y - center.y
        let distance = hypot(dx, dy)

        if distance <= hubRadius {
            // Center: root → flip to media; clipboard → back zone.
            let focus = model.level == .root
            if model.hubFocused != focus { model.hubFocused = focus }
            if model.highlightedIndex != nil { model.highlightedIndex = nil }
            return
        }
        if model.hubFocused { model.hubFocused = false }

        guard count > 0 else { model.highlightedIndex = nil; return }
        let cursorAngle = atan2(dy, dx) * 180.0 / .pi
        var best = 0
        var bestDiff = Double.infinity
        for index in 0..<count {
            let diff = angularDistance(cursorAngle, angleDegrees(for: index, count: count))
            if diff < bestDiff { bestDiff = diff; best = index }
        }
        if model.highlightedIndex != best { model.highlightedIndex = best }
    }

    private func angularDistance(_ a: Double, _ b: Double) -> Double {
        var diff = (a - b).truncatingRemainder(dividingBy: 360)
        if diff < -180 { diff += 360 }
        if diff > 180 { diff -= 360 }
        return abs(diff)
    }
}

// MARK: - Shared modifiers

private struct RingItem: ViewModifier {
    let isHighlighted: Bool
    func body(content: Content) -> some View {
        content
            .scaleEffect(isHighlighted ? 1.2 : 1.0)
            .shadow(color: .black.opacity(isHighlighted ? 0.32 : 0.16),
                    radius: isHighlighted ? 16 : 6, y: isHighlighted ? 5 : 2)
            .zIndex(isHighlighted ? 1 : 0)
    }
}

private struct HubLabel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 10)
            .foregroundStyle(.primary)
    }
}
