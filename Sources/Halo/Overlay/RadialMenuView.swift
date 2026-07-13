import SwiftUI

/// The radial menu itself: a ring of Liquid Glass buttons around a central hub.
/// The cursor's angle from the center selects the nearest item; a click (or
/// Return, handled by the controller) activates it.
struct RadialMenuView: View {
    @ObservedObject var model: RadialMenuModel
    var onSelect: (MenuItem) -> Void
    var onDismiss: () -> Void

    @State private var appeared: Bool

    /// - Parameter startVisible: skip the entrance animation and render fully
    ///   shown. Used for offscreen snapshots/previews where `onAppear` never fires.
    init(
        model: RadialMenuModel,
        startVisible: Bool = false,
        onSelect: @escaping (MenuItem) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self._model = ObservedObject(wrappedValue: model)
        self.onSelect = onSelect
        self.onDismiss = onDismiss
        self._appeared = State(initialValue: startVisible)
    }

    // Geometry. The panel is larger than the ring so hover tracking has room
    // all the way around.
    private let ringRadius: CGFloat = 128
    private let itemSize: CGFloat = 62
    private let hubSize: CGFloat = 96
    private let deadZone: CGFloat = 46

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

            // No GlassEffectContainer: we want independent glass circles, not
            // merged metaball blobs. Merging is what made the highlighted item
            // appear to lurch toward its neighbors on hover.
            ZStack {
                hub
                    .position(center)

                ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
                    itemButton(item, isHighlighted: model.highlightedIndex == index)
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
                    onSelect(model.items[index])
                } else {
                    onDismiss()
                }
            }
        }
        .scaleEffect(appeared ? 1 : 0.92)
        .opacity(appeared ? 1 : 0)
        // Non-bouncy curves for a calm, professional feel.
        .animation(.smooth(duration: 0.24), value: appeared)
        .animation(.smooth(duration: 0.18), value: model.highlightedIndex)
        .onAppear { appeared = true }
    }

    // MARK: - Subviews

    /// Center hub. Content lives *inside* the glass view (not layered over a
    /// clear circle) so SwiftUI gives it proper glass vibrancy and it stays
    /// legible against any background.
    private var hub: some View {
        Group {
            if let index = model.highlightedIndex {
                Text(model.items[index].title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 12)
                    .foregroundStyle(.primary)
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

    /// A ring item. Highlight is expressed purely through a clean scale-up (the
    /// glyph font stays constant so nothing re-layouts) plus a brighter rim and
    /// a deeper shadow — no color tint, no interactive press transform.
    private func itemButton(_ item: MenuItem, isHighlighted: Bool) -> some View {
        Image(systemName: item.systemImage)
            .font(.system(size: 24, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.primary)
            .frame(width: itemSize, height: itemSize)
            .glassEffect(.regular, in: .circle)
            .overlay(
                Circle().strokeBorder(.white.opacity(isHighlighted ? 0.55 : 0.10),
                                      lineWidth: isHighlighted ? 1.5 : 0.75)
            )
            .scaleEffect(isHighlighted ? 1.2 : 1.0)
            .shadow(color: .black.opacity(isHighlighted ? 0.32 : 0.16),
                    radius: isHighlighted ? 16 : 6, y: isHighlighted ? 5 : 2)
            .zIndex(isHighlighted ? 1 : 0)
    }

    // MARK: - Geometry & selection

    /// Item angles start at the top (-90°) and go clockwise.
    private func angleDegrees(for index: Int) -> Double {
        let step = 360.0 / Double(max(model.items.count, 1))
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
        let distance = hypot(dx, dy)

        guard distance > deadZone else {
            if model.highlightedIndex != nil { model.highlightedIndex = nil }
            return
        }

        let cursorAngle = atan2(dy, dx) * 180.0 / .pi
        var best = 0
        var bestDiff = Double.infinity
        for index in model.items.indices {
            let diff = angularDistance(cursorAngle, angleDegrees(for: index))
            if diff < bestDiff {
                bestDiff = diff
                best = index
            }
        }
        if model.highlightedIndex != best { model.highlightedIndex = best }
    }

    /// Smallest absolute difference between two angles in degrees (handles wrap).
    private func angularDistance(_ a: Double, _ b: Double) -> Double {
        var diff = (a - b).truncatingRemainder(dividingBy: 360)
        if diff < -180 { diff += 360 }
        if diff > 180 { diff -= 360 }
        return abs(diff)
    }
}
