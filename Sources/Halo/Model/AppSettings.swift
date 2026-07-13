import Foundation

/// Where the radial menu appears when triggered.
enum OverlayPlacement: String {
    case center // center of the screen under the cursor
    case cursor // at the cursor position
}

/// Lightweight, UserDefaults-backed settings. Phase 3 folds this into the full
/// persisted configuration; for now it just holds the overlay placement.
@MainActor
enum AppSettings {
    private static let placementKey = "overlayPlacement"

    static var placement: OverlayPlacement {
        get {
            let raw = UserDefaults.standard.string(forKey: placementKey) ?? ""
            return OverlayPlacement(rawValue: raw) ?? .center
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: placementKey) }
    }
}
