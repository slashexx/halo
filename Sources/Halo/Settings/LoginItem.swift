import ServiceManagement

/// Start-at-login via the modern ServiceManagement API (macOS 13+).
@MainActor
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Halo: could not update login item: %@", error.localizedDescription)
        }
    }
}
