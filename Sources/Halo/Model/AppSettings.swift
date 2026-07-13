import Foundation

/// Where the radial menu appears when triggered.
enum OverlayPlacement: String, CaseIterable, Identifiable {
    case center // center of the screen under the cursor
    case cursor // at the cursor position

    var id: String { rawValue }
    var title: String {
        switch self {
        case .center: "Center of screen"
        case .cursor: "At cursor"
        }
    }
}

/// How the user selects from the wheel.
enum GestureMode: String, CaseIterable, Identifiable {
    case both        // tap = sticky (click to pick); hold = release to pick
    case holdRelease // hold ⌥Tab, navigate, release to pick
    case pressToggle // press ⌥Tab to open, click / Return to pick

    var id: String { rawValue }
    var title: String {
        switch self {
        case .both: "Tap to open, or hold & release"
        case .holdRelease: "Hold & release to pick"
        case .pressToggle: "Press to open, click to pick"
        }
    }
}

/// Lightweight, UserDefaults-backed settings.
@MainActor
enum AppSettings {
    private static let placementKey = "overlayPlacement"
    private static let gestureKey = "gestureMode"
    private static let clipboardDelayKey = "clipboardHoverDelay"

    static var placement: OverlayPlacement {
        get { OverlayPlacement(rawValue: UserDefaults.standard.string(forKey: placementKey) ?? "") ?? .center }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: placementKey) }
    }

    static var gestureMode: GestureMode {
        get { GestureMode(rawValue: UserDefaults.standard.string(forKey: gestureKey) ?? "") ?? .both }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: gestureKey) }
    }

    /// How long to hover the Clipboard slot before its side-panel opens.
    static var clipboardHoverDelay: Double {
        get {
            let value = UserDefaults.standard.double(forKey: clipboardDelayKey)
            return value == 0 ? 0.6 : value
        }
        set { UserDefaults.standard.set(newValue, forKey: clipboardDelayKey) }
    }
}
