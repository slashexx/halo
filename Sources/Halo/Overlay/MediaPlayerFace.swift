import AppKit
import SwiftUI

/// The back face of the hub: album-art-themed now-playing with transport
/// controls. Drag left/right to switch between active sources.
struct MediaPlayerFace: View {
    @ObservedObject var media: MediaHubModel
    let size: CGFloat

    var body: some View {
        ZStack {
            background
            Circle().fill(.black.opacity(0.4))
            content
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    if value.translation.width < -24 { media.switchNext() }
                    else if value.translation.width > 24 { media.switchPrevious() }
                }
        )
    }

    @ViewBuilder
    private var background: some View {
        if let art = media.artwork {
            Image(nsImage: art).resizable().scaledToFill()
        } else {
            LinearGradient(colors: [.indigo, .purple], startPoint: .top, endPoint: .bottom)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let now = media.current {
            VStack(spacing: 5) {
                Text(now.title)
                    .font(.system(size: 12, weight: .semibold)).lineLimit(1)
                Text(now.artist.isEmpty ? now.appName : now.artist)
                    .font(.system(size: 10)).opacity(0.85).lineLimit(1)

                HStack(spacing: 14) {
                    control("backward.fill", size: 15) { media.previous() }
                    control(now.isPlaying ? "pause.fill" : "play.fill", size: 20) { media.playPause() }
                    control("forward.fill", size: 15) { media.next() }
                }
                .padding(.top, 2)

                if media.hasMultiple { dots }
            }
            .padding(.horizontal, 14)
            .foregroundStyle(.white)
        } else {
            VStack(spacing: 4) {
                Image(systemName: "music.note").font(.system(size: 22, weight: .medium))
                Text("Nothing playing").font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(.white.opacity(0.9))
        }
    }

    private func control(_ symbol: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: size, weight: .semibold))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
    }

    private var dots: some View {
        HStack(spacing: 5) {
            ForEach(0..<media.sources.count, id: \.self) { index in
                Circle()
                    .fill(.white.opacity(index == media.currentIndex ? 0.95 : 0.4))
                    .frame(width: 5, height: 5)
            }
        }
        .padding(.top, 1)
    }
}
