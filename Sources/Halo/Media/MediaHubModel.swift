import AppKit
import SwiftUI

/// Drives the center media hub: which sources are active, which one is focused,
/// its resolved artwork, and the transport controls.
@MainActor
final class MediaHubModel: ObservableObject {
    @Published private(set) var sources: [NowPlaying] = []
    @Published var currentIndex = 0
    @Published private(set) var artwork: NSImage?

    private let providers: [MediaProvider] = [SpotifyProvider(), MusicProvider(), BrowserMediaProvider()]

    var current: NowPlaying? {
        sources.indices.contains(currentIndex) ? sources[currentIndex] : nil
    }
    var hasMultiple: Bool { sources.count > 1 }

    func refresh() {
        let previousID = current?.bundleID
        sources = providers.compactMap { $0.fetch() }

        if let previousID, let index = sources.firstIndex(where: { $0.bundleID == previousID }) {
            currentIndex = index
        } else if currentIndex >= sources.count {
            currentIndex = 0
        }
        resolveArtwork()
    }

    func switchNext() {
        guard !sources.isEmpty else { return }
        currentIndex = (currentIndex + 1) % sources.count
        resolveArtwork()
    }

    func switchPrevious() {
        guard !sources.isEmpty else { return }
        currentIndex = (currentIndex - 1 + sources.count) % sources.count
        resolveArtwork()
    }

    func playPause() { provider(current)?.playPause(); refreshSoon() }
    func next() { provider(current)?.next(); refreshSoon() }
    func previous() { provider(current)?.previous(); refreshSoon() }

    // MARK: - Private

    private func provider(_ nowPlaying: NowPlaying?) -> MediaProvider? {
        providers.first { $0.bundleID == nowPlaying?.bundleID }
    }

    private func refreshSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.refresh() }
    }

    private func resolveArtwork() {
        guard let current else { artwork = nil; return }
        if let image = current.artwork { artwork = image; return }

        artwork = nil
        guard let urlString = current.artworkURL, let url = URL(string: urlString) else { return }
        let targetID = current.bundleID
        Task { [weak self] in
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = NSImage(data: data) else { return }
            await MainActor.run {
                guard let self, self.current?.bundleID == targetID else { return }
                self.artwork = image
            }
        }
    }
}
