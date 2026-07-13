import AppKit
@preconcurrency import ApplicationServices

/// Repositions the frontmost window via the Accessibility API. Requires
/// Accessibility permission (setting another app's window frame).
@MainActor
enum WindowManager {
    static func move(_ position: WindowPosition) {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            NSLog("Halo: no frontmost app to move.")
            return
        }

        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        guard let window = focusedWindow(of: axApp) else {
            NSLog("Halo: couldn't get a window for %@ (is Accessibility granted?).", app.localizedName ?? "app")
            return
        }

        // Use the screen under the cursor (where the wheel was triggered).
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }
            ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }

        let target = axFrame(from: frame(for: position, in: visible))
        // Set position → size → position again; some apps clamp on the first pass.
        setPoint(window, kAXPositionAttribute, target.origin)
        setSize(window, target.size)
        setPoint(window, kAXPositionAttribute, target.origin)
    }

    // MARK: - Window lookup

    private static func focusedWindow(of axApp: AXUIElement) -> AXUIElement? {
        var ref: CFTypeRef?
        if AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &ref) == .success,
           let ref { return (ref as! AXUIElement) }

        var windowsRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef) == .success,
           let windows = windowsRef as? [AXUIElement], let first = windows.first {
            return first
        }
        return nil
    }

    // MARK: - Geometry

    private static func frame(for position: WindowPosition, in v: CGRect) -> CGRect {
        switch position {
        case .leftHalf: return CGRect(x: v.minX, y: v.minY, width: v.width / 2, height: v.height)
        case .rightHalf: return CGRect(x: v.midX, y: v.minY, width: v.width / 2, height: v.height)
        case .topHalf: return CGRect(x: v.minX, y: v.midY, width: v.width, height: v.height / 2)
        case .bottomHalf: return CGRect(x: v.minX, y: v.minY, width: v.width, height: v.height / 2)
        case .maximize: return v
        case .center:
            let w = v.width * 0.6, h = v.height * 0.72
            return CGRect(x: v.midX - w / 2, y: v.midY - h / 2, width: w, height: h)
        }
    }

    /// NSScreen frames are bottom-left origin; the Accessibility API is
    /// top-left origin relative to the primary display.
    private static func axFrame(from ns: CGRect) -> CGRect {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? ns.maxY
        return CGRect(x: ns.minX, y: primaryHeight - ns.maxY, width: ns.width, height: ns.height)
    }

    private static func setPoint(_ window: AXUIElement, _ attribute: String, _ point: CGPoint) {
        var value = point
        if let axValue = AXValueCreate(.cgPoint, &value) {
            AXUIElementSetAttributeValue(window, attribute as CFString, axValue)
        }
    }

    private static func setSize(_ window: AXUIElement, _ size: CGSize) {
        var value = size
        if let axValue = AXValueCreate(.cgSize, &value) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, axValue)
        }
    }
}
