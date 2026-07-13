import Foundation

/// Persists the wheel's slots as JSON in Application Support so customizations
/// survive relaunch. `nil` slots (empty positions) encode as `null`.
@MainActor
enum MenuStore {
    private static var fileURL: URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Halo", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("menu.json")
    }

    /// Returns the saved slots, or `nil` if the user hasn't customized yet.
    static func load() -> [MenuItem?]? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode([MenuItem?].self, from: data)
    }

    static func save(_ slots: [MenuItem?]) {
        guard let data = try? JSONEncoder().encode(slots) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
