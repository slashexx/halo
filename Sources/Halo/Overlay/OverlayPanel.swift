import AppKit

/// A transparent, borderless, non-activating panel that floats above everything.
/// Non-activating means summoning the menu does NOT steal foreground status from
/// the app you're working in — important so actions can target that app later.
/// It can still become key to receive mouse-moved and keyboard events.
final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init(size: NSSize) {
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .popUpMenu
        isMovable = false
        hidesOnDeactivate = false
        acceptsMouseMovedEvents = true
        ignoresMouseEvents = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        animationBehavior = .none
    }
}
