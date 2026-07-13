import AppKit
import CoreGraphics

/// Surfaces a media tab (YouTube, Twitch, etc.) playing in a running browser as
/// a media source. macOS 26 blocks true system now-playing, so this is
/// best-effort: the name comes from the active tab title, and transport uses
/// system media keys (which target whatever the system is currently playing).
struct BrowserMediaProvider: MediaProvider {
    // Sentinel id so MediaHubModel can route controls back here regardless of
    // which browser is actually in front.
    let bundleID = "halo.browser.media"
    var appName = "Browser"

    private struct Browser { let id, name, script: String }

    /// Chromium-family and Safari use slightly different tab vocabulary.
    private static let browsers: [Browser] = [
        Browser(id: "com.google.Chrome", name: "Chrome", script: chromium("Google Chrome")),
        Browser(id: "com.brave.Browser", name: "Brave", script: chromium("Brave Browser")),
        Browser(id: "com.microsoft.edgemac", name: "Edge", script: chromium("Microsoft Edge")),
        Browser(id: "company.thebrowser.Browser", name: "Arc", script: chromium("Arc")),
        Browser(id: "com.apple.Safari", name: "Safari", script: safari()),
    ]

    private static let mediaHosts = [
        "youtube.com", "youtu.be", "music.youtube.com", "soundcloud.com",
        "twitch.tv", "vimeo.com", "netflix.com", "open.spotify.com",
        "music.apple.com", "primevideo.com", "bandcamp.com",
    ]

    func fetch() -> NowPlaying? {
        for browser in Self.browsers {
            guard !NSRunningApplication.runningApplications(withBundleIdentifier: browser.id).isEmpty,
                  let raw = runAppleScript(browser.script), !raw.isEmpty else { continue }

            let parts = raw.components(separatedBy: "\u{001F}")
            guard parts.count == 2, isMedia(parts[1]) else { continue }

            return NowPlaying(
                bundleID: bundleID, appName: browser.name,
                title: cleanTitle(parts[0]), artist: browser.name,
                isPlaying: true, artworkURL: nil, artwork: nil
            )
        }
        return nil
    }

    func playPause() { Self.postMediaKey(16) } // NX_KEYTYPE_PLAY
    func next() { Self.postMediaKey(17) }       // NX_KEYTYPE_NEXT
    func previous() { Self.postMediaKey(18) }   // NX_KEYTYPE_PREVIOUS

    // MARK: - Helpers

    private func isMedia(_ urlString: String) -> Bool {
        guard let host = URL(string: urlString)?.host?.lowercased() else { return false }
        return Self.mediaHosts.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    private func cleanTitle(_ title: String) -> String {
        var result = title
        for suffix in [" - YouTube", " - YouTube Music", " on Vimeo", " - Twitch"] {
            if result.hasSuffix(suffix) { result = String(result.dropLast(suffix.count)) }
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    private static func chromium(_ app: String) -> String {
        """
        tell application "\(app)"
            if (count of windows) is 0 then return ""
            set _t to title of active tab of front window
            set _u to URL of active tab of front window
            return _t & "\u{001F}" & _u
        end tell
        """
    }

    private static func safari() -> String {
        """
        tell application "Safari"
            if (count of windows) is 0 then return ""
            set _t to name of current tab of front window
            set _u to URL of current tab of front window
            return _t & "\u{001F}" & _u
        end tell
        """
    }

    /// Posts a system media key (down+up) via a systemDefined event.
    private static func postMediaKey(_ key: Int32) {
        func send(_ down: Bool) {
            let data1 = (Int(key) << 16) | ((down ? 0xA : 0xB) << 8)
            let flags = NSEvent.ModifierFlags(rawValue: UInt(down ? 0xA00 : 0xB00))
            guard let event = NSEvent.otherEvent(
                with: .systemDefined, location: .zero, modifierFlags: flags,
                timestamp: 0, windowNumber: 0, context: nil,
                subtype: 8, data1: data1, data2: -1
            ) else { return }
            event.cgEvent?.post(tap: .cghidEventTap)
        }
        send(true)
        send(false)
    }
}
