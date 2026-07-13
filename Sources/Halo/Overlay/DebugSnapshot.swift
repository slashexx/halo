import AppKit
import SwiftUI

/// Renders the radial menu to a PNG entirely in-process (via `ImageRenderer`),
/// so it can be inspected without Screen Recording permission. Enabled by the
/// RADIAL_DEBUG_SNAPSHOT=<path> environment variable.
@MainActor
enum DebugSnapshot {
    static func render(to path: String) {
        let model = RadialMenuModel()
        model.highlightedIndex = 2 // show a highlighted item

        let content = ZStack {
            // Stand-in desktop so the glass has something to refract.
            LinearGradient(
                colors: [.blue, .purple, .pink, .orange],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialMenuView(model: model, startVisible: true,
                           onActivate: { _ in }, onEdit: { _ in },
                           onClear: { _ in }, onDismiss: {})
        }
        .frame(width: 420, height: 420)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 2

        guard
            let image = renderer.nsImage,
            let tiff = image.tiffRepresentation,
            let rep = NSBitmapImageRep(data: tiff),
            let png = rep.representation(using: .png, properties: [:])
        else {
            NSLog("Halo: snapshot render failed")
            return
        }

        do {
            try png.write(to: URL(fileURLWithPath: path))
            NSLog("Halo: snapshot written to %@", path)
        } catch {
            NSLog("Halo: snapshot write failed: %@", error.localizedDescription)
        }
    }
}
