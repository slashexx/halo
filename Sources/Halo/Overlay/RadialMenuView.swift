import AppKit
import SwiftUI

/// The radial menu: a ring of nodes around a central hub. At the root level a
/// node is a slot (filled → runs an action / clipboard → opens a sub-menu,
/// empty → ＋ to add). In the clipboard sub-menu each node is a recent copy.
struct RadialMenuView: View {
    @ObservedObject var model: RadialMenuModel

    var onActivate: (Int) -> Void   // left-click / Return on a node
    var onEdit: (Int) -> Void       // set or replace a slot
    var onClear: (Int) -> Void      // empty a slot
    var onBack: () -> Void          // leave a sub-menu
    var onDismiss: () -> Void

    @State private var appeared: Bool

    private let ringRadius: CGFloat = 128
    private let itemSize: CGFloat = 62
    private let hubSize: CGFloat = 96
    private let deadZone: CGFloat = 46

    init(
        model: RadialMenuModel,
        startVisible: Bool = false,
        onActivate: @escaping (Int) -> Void,
        onEdit: @escaping (Int) -> Void,
        onClear: @escaping (Int) -> Void,
        onBack: @escaping () -> Void = {},
        onDismiss: @escaping () -> Void
    ) {
        self._model = ObservedObject(wrappedValue: model)
        self.onActivate = onActivate
        self.onEdit = onEdit
        self.onClear = onClear
        self.onBack = onBack
        self.onDismiss = onDismiss
        self._appeared = State(initialValue: startVisible)
    }

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let nodes = model.nodes

            ZStack {
                hub.position(center)

                ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                    nodeView(node, index: index, isHighlighted: model.highlightedIndex == index)
                        .position(position(for: index, count: nodes.count, center: center))
                }
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                if case .active(let location) = phase {
                    updateHighlight(at: location, center: center, count: nodes.count)
                }
            }
            .onTapGesture {
                if let index = model.highlightedIndex {
                    onActivate(index)
                } else if model.level == .root {
                    onDismiss()
                } else {
                    onBack()
                }
            }
            // Dwell on the clipboard slot opens its sub-menu (so a held ⌥Tab can
            // flow straight into it and release on an entry).
            .task(id: dwellKey) {
                guard model.level == .root, let index = model.highlightedIndex,
                      model.isClipboardSlot(index) else { return }
                try? await Task.sleep(for: .milliseconds(220))
                if model.highlightedIndex == index, model.level == .root {
                    model.enterClipboard()
                }
            }
        }
        .scaleEffect(appeared ? 1 : 0.92)
        .opacity(appeared ? 1 : 0)
        .animation(.smooth(duration: 0.24), value: appeared)
        .animation(.smooth(duration: 0.18), value: model.highlightedIndex)
        .animation(.smooth(duration: 0.22), value: model.level)
        .onAppear { appeared = true }
    }

    private var dwellKey: String { "\(model.level == .root ? "r" : "c")-\(model.highlightedIndex ?? -1)" }

    // MARK: - Hub

    private var hub: some View {
        Group {
            if model.level == .clipboard {
                clipboardHub
            } else if let index = model.highlightedIndex {
                if let item = model.slots[safe: index] ?? nil {
                    Text(item.title).modifier(HubLabel())
                } else {
                    VStack(spacing: 2) {
                        Image(systemName: "plus.circle.fill").font(.system(size: 20, weight: .semibold))
                        Text("Add").font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.primary)
                }
            } else {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.primary)
            }
        }
        .frame(width: hubSize, height: hubSize)
        .glassEffect(.regular, in: .circle)
        .shadow(color: .black.opacity(0.16), radius: 9, y: 2)
    }

    private var clipboardHub: some View {
        VStack(spacing: 3) {
            if let index = model.highlightedIndex, case .clip(let entry)? = model.node(at: index) {
                Text(entry.summary).modifier(HubLabel())
            } else {
                Image(systemName: "chevron.backward").font(.system(size: 16, weight: .semibold))
                Text(model.nodeCount == 0 ? "Empty" : "Clipboard")
                    .font(.system(size: 12, weight: .medium))
            }
        }
        .foregroundStyle(.primary)
    }

    // MARK: - Node views

    @ViewBuilder
    private func nodeView(_ node: WheelNode, index: Int, isHighlighted: Bool) -> some View {
        switch node {
        case .slot(let slotIndex, let item):
            if let item {
                iconView(item.icon)
                    .frame(width: itemSize, height: itemSize)
                    .glassEffect(.regular, in: .circle)
                    .modifier(RingItem(isHighlighted: isHighlighted))
                    .contextMenu {
                        if item.kind == .action, case .chain? = item.action {
                            Button("Edit workflow…") { onEdit(slotIndex) }
                        }
                        Button("Replace…") { onEdit(slotIndex) }
                        Button("Remove", role: .destructive) { onClear(slotIndex) }
                    }
            } else {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: itemSize, height: itemSize)
                    .glassEffect(.regular, in: .circle)
                    .overlay(
                        Circle().strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                            .foregroundStyle(.white.opacity(isHighlighted ? 0.45 : 0.18))
                    )
                    .modifier(RingItem(isHighlighted: isHighlighted))
                    .contextMenu { Button("Add…") { onEdit(slotIndex) } }
            }

        case .clip(let entry):
            ClipThumbnailView(entry: entry, size: itemSize)
                .overlay(Circle().strokeBorder(.white.opacity(isHighlighted ? 0.55 : 0.12),
                                               lineWidth: isHighlighted ? 1.5 : 0.75))
                .modifier(RingItem(isHighlighted: isHighlighted))
        }
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
        guard count > 0 else { model.highlightedIndex = nil; return }
        let dx = location.x - center.x
        let dy = location.y - center.y
        guard hypot(dx, dy) > deadZone else {
            if model.highlightedIndex != nil { model.highlightedIndex = nil }
            return
        }

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

// MARK: - Shared modifiers / helpers

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
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 12)
            .foregroundStyle(.primary)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
