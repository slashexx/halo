import AppKit
import SwiftUI

/// The radial menu: a ring of slots around a hub. The Clipboard slot opens a
/// list that slides in *beside* the wheel (the wheel stays visible). A filled
/// slot runs an action; an empty slot shows ＋ to add.
struct RadialMenuView: View {
    @ObservedObject var model: RadialMenuModel
    @ObservedObject var media: MediaHubModel

    var onActivate: (Int) -> Void        // ring slot
    var onActivateClip: (Int) -> Void    // clipboard row
    var onEdit: (Int) -> Void            // set or replace a slot
    var onEditWorkflow: (Int) -> Void    // edit a workflow slot
    var onClear: (Int) -> Void           // empty a slot
    var onCloseClipboard: () -> Void
    var onDismiss: () -> Void

    @State private var appeared: Bool

    private let ringRadius: CGFloat = 132
    private let itemSize: CGFloat = 60
    private let hubSize: CGFloat = 160
    private var hubRadius: CGFloat { hubSize / 2 }
    private let listOffsetX: CGFloat = 320

    init(
        model: RadialMenuModel,
        media: MediaHubModel = MediaHubModel(),
        startVisible: Bool = false,
        onActivate: @escaping (Int) -> Void,
        onActivateClip: @escaping (Int) -> Void = { _ in },
        onEdit: @escaping (Int) -> Void,
        onEditWorkflow: @escaping (Int) -> Void = { _ in },
        onClear: @escaping (Int) -> Void,
        onCloseClipboard: @escaping () -> Void = {},
        onDismiss: @escaping () -> Void
    ) {
        self._model = ObservedObject(wrappedValue: model)
        self._media = ObservedObject(wrappedValue: media)
        self.onActivate = onActivate
        self.onActivateClip = onActivateClip
        self.onEdit = onEdit
        self.onEditWorkflow = onEditWorkflow
        self.onClear = onClear
        self.onCloseClipboard = onCloseClipboard
        self.onDismiss = onDismiss
        self._appeared = State(initialValue: startVisible)
    }

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

            ZStack {
                ring(center: center)

                if model.clipboardOpen {
                    ClipboardListView(model: model, onActivate: onActivateClip, onBack: onCloseClipboard)
                        .position(x: center.x + listOffsetX, y: center.y)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        .scaleEffect(appeared ? 1 : 0.92)
        .opacity(appeared ? 1 : 0)
        .animation(.smooth(duration: 0.24), value: appeared)
        .animation(.smooth(duration: 0.18), value: model.highlightedIndex)
        .animation(.smooth(duration: 0.24), value: model.clipboardOpen)
        .onAppear { appeared = true }
    }

    private func ring(center: CGPoint) -> some View {
        ZStack {
            hub.position(center)

            ForEach(0..<model.slotCountValue, id: \.self) { index in
                slotView(index: index, isHighlighted: model.highlightedIndex == index)
                    .position(position(for: index, count: model.slotCountValue, center: center))
            }
        }
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            guard !model.clipboardOpen else { return } // frozen while the list is open
            if case .active(let location) = phase {
                updateHighlight(at: location, center: center, count: model.slotCountValue)
            }
        }
        .onTapGesture {
            if model.clipboardOpen {
                onCloseClipboard()
            } else if model.hubFocused {
                // Taps on the hub are handled by the player's own controls.
            } else if let index = model.highlightedIndex {
                onActivate(index)
            } else {
                onDismiss()
            }
        }
        // Dwell on the Clipboard slot opens its side-panel. Delay is configurable
        // so a quick pass (e.g. to right-click → Remove) doesn't trigger it.
        .task(id: dwellKey) {
            guard !model.clipboardOpen, let index = model.highlightedIndex,
                  model.isClipboardSlot(index) else { return }
            try? await Task.sleep(for: .seconds(AppSettings.clipboardHoverDelay))
            if model.highlightedIndex == index, !model.clipboardOpen {
                model.openClipboard()
            }
        }
        // Keep the media hub fresh while the cursor is on it.
        .task(id: model.hubFocused) {
            guard model.hubFocused else { return }
            media.refresh()
            while !Task.isCancelled && model.hubFocused {
                try? await Task.sleep(for: .seconds(1.2))
                if model.hubFocused { media.refresh() }
            }
        }
    }

    private var dwellKey: String {
        "\(model.clipboardOpen ? "c" : "r")-\(model.highlightedIndex ?? -1)"
    }

    // MARK: - Hub

    private var hub: some View {
        ZStack {
            hubFront
                .frame(width: hubSize, height: hubSize)
                .glassEffect(.regular, in: .circle)
                .opacity(model.hubFocused ? 0 : 1)

            MediaPlayerFace(media: media, size: hubSize)
                .opacity(model.hubFocused ? 1 : 0)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0)) // un-mirror
        }
        .rotation3DEffect(.degrees(model.hubFocused ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        .shadow(color: .black.opacity(0.18), radius: 12, y: 3)
        .animation(.smooth(duration: 0.38), value: model.hubFocused)
    }

    @ViewBuilder
    private var hubFront: some View {
        if let index = model.highlightedIndex, let item = model.item(at: index) {
            Text(item.title).modifier(HubLabel())
        } else if model.highlightedIndex != nil {
            VStack(spacing: 2) {
                Image(systemName: "plus.circle.fill").font(.system(size: 22, weight: .semibold))
                Text("Add").font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(.primary)
        } else {
            VStack(spacing: 4) {
                Image(systemName: "play.circle").font(.system(size: 26, weight: .medium))
                Text("Media").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
        }
    }

    // MARK: - Slot views

    @ViewBuilder
    private func slotView(index: Int, isHighlighted: Bool) -> some View {
        if let item = model.item(at: index) {
            iconView(item.icon)
                .frame(width: itemSize, height: itemSize)
                .glassEffect(.regular, in: .circle)
                .modifier(RingItem(isHighlighted: isHighlighted))
                .contextMenu {
                    if item.kind == .action, case .chain? = item.action {
                        Button("Edit workflow…") { onEditWorkflow(index) }
                    }
                    Button("Replace…") { onEdit(index) }
                    Button("Remove", role: .destructive) { onClear(index) }
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
                .contextMenu { Button("Add…") { onEdit(index) } }
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
        let dx = location.x - center.x
        let dy = location.y - center.y
        let distance = hypot(dx, dy)

        // Inside the hub circle → focus the media player, no ring selection.
        if distance <= hubRadius {
            if !model.hubFocused { model.hubFocused = true }
            if model.highlightedIndex != nil { model.highlightedIndex = nil }
            return
        }
        if model.hubFocused { model.hubFocused = false }

        guard count > 0 else { model.highlightedIndex = nil; return }
        guard distance > hubRadius else {
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
