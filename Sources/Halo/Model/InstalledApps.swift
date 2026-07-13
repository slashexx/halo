import AppKit

/// A discovered application on disk.
struct InstalledApp: Identifiable, Hashable {
    var id: String { path }
    let name: String
    let path: String
}

/// Enumerates installed apps for the "add to wheel" picker.
@MainActor
enum InstalledApps {
    private static let searchDirectories = [
        "/Applications",
        "/Applications/Utilities",
        "/System/Applications",
        "/System/Applications/Utilities",
        NSHomeDirectory() + "/Applications",
    ]

    static func all() -> [InstalledApp] {
        let fileManager = FileManager.default
        var byName: [String: InstalledApp] = [:]

        for directory in searchDirectories {
            guard let entries = try? fileManager.contentsOfDirectory(atPath: directory) else { continue }
            for entry in entries where entry.hasSuffix(".app") {
                let name = String(entry.dropLast(4))
                byName[name] = InstalledApp(name: name, path: directory + "/" + entry)
            }
        }

        return byName.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
}
