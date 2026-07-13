import AppKit

// Halo is a menu-bar agent app (no Dock icon, LSUIElement=true in Info.plist).
// We drive NSApplication directly rather than using the SwiftUI App lifecycle so
// we have full control over the borderless overlay panel summoned by the hotkey.
let delegate = AppDelegate()
let app = NSApplication.shared
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
