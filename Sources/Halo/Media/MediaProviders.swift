import AppKit

/// A snapshot of one media source's current track.
struct NowPlaying {
    var bundleID: String
    var appName: String
    var title: String
    var artist: String
    var isPlaying: Bool
    var artworkURL: String?   // Spotify provides a URL
    var artwork: NSImage?     // Music provides raw image data
}

/// A controllable media source. Rich sources (Spotify, Music) are scripted via
/// AppleScript; browser/media-key sources will be added later.
@MainActor
protocol MediaProvider {
    var bundleID: String { get }
    var appName: String { get }
    func fetch() -> NowPlaying?   // nil if not running / stopped
    func playPause()
    func next()
    func previous()
}

/// Runs AppleScript, returning its string result (nil on error, e.g. Automation
/// permission not yet granted).
@MainActor
func runAppleScript(_ source: String) -> String? {
    var error: NSDictionary?
    let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
    if error != nil { return nil }
    return result?.stringValue
}

@MainActor
private func isRunning(_ bundleID: String) -> Bool {
    !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
}

// MARK: - Spotify

struct SpotifyProvider: MediaProvider {
    let bundleID = "com.spotify.client"
    let appName = "Spotify"

    func fetch() -> NowPlaying? {
        guard isRunning(bundleID) else { return nil }
        let script = """
        tell application "Spotify"
            if player state is stopped then return ""
            set _t to name of current track
            set _a to artist of current track
            set _u to artwork url of current track
            set _p to (player state as string)
            return _t & "\u{001F}" & _a & "\u{001F}" & _u & "\u{001F}" & _p
        end tell
        """
        guard let raw = runAppleScript(script), !raw.isEmpty else { return nil }
        let parts = raw.components(separatedBy: "\u{001F}")
        guard parts.count == 4 else { return nil }
        return NowPlaying(
            bundleID: bundleID, appName: appName,
            title: parts[0], artist: parts[1],
            isPlaying: parts[3] == "playing",
            artworkURL: parts[2].isEmpty ? nil : parts[2], artwork: nil
        )
    }

    func playPause() { _ = runAppleScript(#"tell application "Spotify" to playpause"#) }
    func next() { _ = runAppleScript(#"tell application "Spotify" to next track"#) }
    func previous() { _ = runAppleScript(#"tell application "Spotify" to previous track"#) }
}

// MARK: - Apple Music

struct MusicProvider: MediaProvider {
    let bundleID = "com.apple.Music"
    let appName = "Music"

    func fetch() -> NowPlaying? {
        guard isRunning(bundleID) else { return nil }
        let script = """
        tell application "Music"
            if player state is stopped then return ""
            set _t to name of current track
            set _a to artist of current track
            set _p to (player state as string)
            return _t & "\u{001F}" & _a & "\u{001F}" & _p
        end tell
        """
        guard let raw = runAppleScript(script), !raw.isEmpty else { return nil }
        let parts = raw.components(separatedBy: "\u{001F}")
        guard parts.count == 3 else { return nil }
        return NowPlaying(
            bundleID: bundleID, appName: appName,
            title: parts[0], artist: parts[1],
            isPlaying: parts[2] == "playing",
            artworkURL: nil, artwork: artwork()
        )
    }

    /// Apple Music exposes artwork as raw image data over Apple events.
    private func artwork() -> NSImage? {
        var error: NSDictionary?
        let script = NSAppleScript(source: """
        tell application "Music"
            try
                return raw data of artwork 1 of current track
            end try
        end tell
        """)
        guard let descriptor = script?.executeAndReturnError(&error), error == nil else { return nil }
        return NSImage(data: descriptor.data)
    }

    func playPause() { _ = runAppleScript(#"tell application "Music" to playpause"#) }
    func next() { _ = runAppleScript(#"tell application "Music" to next track"#) }
    func previous() { _ = runAppleScript(#"tell application "Music" to previous track"#) }
}
