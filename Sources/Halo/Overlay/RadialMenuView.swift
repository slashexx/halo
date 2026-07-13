import AppKit
import SwiftUI

/// The radial menu: a ring of slots around a central hub. Filled slots show an
/// icon and run an action; empty slots show a ＋ and open the app picker. The
/// cursor's angle from the center selects the nearest slot.
struct RadialMenuView: View {
    @ObservedObject var model: RadialMenuModel

    var onActivate: (Int) -> Void   // left-click / Return on a slot
    var onEdit: (Int) -> Void       // set or replace a slot
    var onClear: (Int) -> Void      // empty a slot
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
        onDismiss: @escaping () -> Void
    ) {
        self._model = ObservedObject(wrappedValue: model)
        self.onActivate = onActivate
        self.onEdit = onEdit
        self.onClear = onClear
        self.onDismiss = onDismiss
        self._appeared = State(initialValue: startVisible)
    }

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

            // Independent glass circles (no GlassEffectContainer, which would
            // merge them into blobs and make the hovered item lurch).
            ZStack {
                hub.position(center)

                ForEach(0..<model.slotCount, id: \.self) { index in
                    slotView(index: index, isHighlighted: model.highlightedIndex == index)
                        .position(position(for: index, center: center))
                }
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                if case .active(let location) = phase {
                    updateHighlight(at: location, center: center)
                }
            }
            .onTapGesture {
                if let index = model.highlightedIndex {
                    onActivate(index)
                } else {
                    onDismiss()
                }
            }
        }
        .scaleEffect(appeared ? 1 : 0.92)
        .opacity(appeared ? 1 : 0)
        .animation(.smooth(duration: 0.24), value: appeared)
        .animation(.smooth(duration: 0.18), value: model.highlightedIndex)
        .onAppear { appeared = true }
    }

    // MARK: - Subviews

    private var hub: some View {
        Group {
            if let index = model.highlightedIndex {
                if let item = model.slots[index] {
                    Text(item.title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 12)
                        .foregroundStyle(.primary)
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

    @ViewBuilder
    private func slotView(index: Int, isHighlighted: Bool) -> some View {
        if let item = model.slots[index] {
            filledSlot(item, isHighlighted: isHighlighted)
                .contextMenu {
                    Button("Replace…") { onEdit(index) }
                    Button("Remove", role: .destructive) { onClear(index) }
                }
        } else {
            emptySlot(isHighlighted: isHighlighted)
                .contextMenu {
                    Button("Add…") { onEdit(index) }
                }
        }
    }

    private func filledSlot(_ item: MenuItem, isHighlighted: Bool) -> some View {
        iconView(item.icon)
            .frame(width: itemSize, height: itemSize)
            .glassEffect(.regular, in: .circle)
            .overlay(rim(isHighlighted: isHighlighted))
            .scaleEffect(isHighlighted ? 1.2 : 1.0)
            .shadow(color: .black.opacity(isHighlighted ? 0.32 : 0.16),
                    radius: isHighlighted ? 16 : 6, y: isHighlighted ? 5 : 2)
            .zIndex(isHighlighted ? 1 : 0)
    }

    private func emptySlot(isHighlighted: Bool) -> some View {
        Image(systemName: "plus")
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: itemSize, height: itemSize)
            .glassEffect(.regular, in: .circle)
            .overlay(
                Circle().strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                    .foregroundStyle(.white.opacity(isHighlighted ? 0.45 : 0.18))
            )
            .scaleEffect(isHighlighted ? 1.2 : 1.0)
            .shadow(color: .black.opacity(isHighlighted ? 0.28 : 0.12),
                    radius: isHighlighted ? 14 : 5, y: isHighlighted ? 4 : 2)
            .zIndex(isHighlighted ? 1 : 0)
    }

    private func rim(isHighlighted: Bool) -> some View {
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
                .resizable()
                .frame(width: 34, height: 34)
        }
    }

    // MARK: - Geometry & selection

    private func angleDegrees(for index: Int) -> Double {
        let step = 360.0 / Double(max(model.slotCount, 1))
        return -90.0 + step * Double(index)
    }

    private func position(for index: Int, center: CGPoint) -> CGPoint {
        let radians = angleDegrees(for: index) * .pi / 180.0
        return CGPoint(x: center.x + cos(radians) * ringRadius,
                       y: center.y + sin(radians) * ringRadius)
    }

    private func updateHighlight(at location: CGPoint, center: CGPoint) {
        let dx = location.x - center.x
        let dy = location.y - center.y
        guard hypot(dx, dy) > deadZone else {
            if model.highlightedIndex != nil { model.highlightedIndex = nil }
            return
        }

        let cursorAngle = atan2(dy, dx) * 180.0 / .pi
        var best = 0
        var bestDiff = Double.infinity
        for index in 0..<model.slotCount {
            let diff = angularDistance(cursorAngle, angleDegrees(for: index))
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
