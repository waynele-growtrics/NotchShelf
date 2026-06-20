import SwiftUI

/// Compact now-playing strip: artwork, track/artist, and transport controls.
/// Falls back to an idle row when nothing is playing (or the private API is
/// unavailable on this macOS version).
struct NowPlayingView: View {
    @ObservedObject var model: NowPlayingModel

    var body: some View {
        HStack(spacing: 10) {
            artwork
            VStack(alignment: .leading, spacing: 1) {
                Text(model.hasTrack ? model.title : "Nothing playing")
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Text(model.hasTrack ? model.artist : "Start a track to see it here")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if model.hasTrack {
                controls
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var artwork: some View {
        Group {
            if let art = model.artwork {
                Image(nsImage: art).resizable().aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color.white.opacity(0.08)
                    Image(systemName: "music.note")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 38, height: 38)
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private var controls: some View {
        HStack(spacing: 14) {
            transportButton("backward.fill") { model.previous() }
            transportButton(model.isPlaying ? "pause.fill" : "play.fill") { model.togglePlayPause() }
            transportButton("forward.fill") { model.next() }
        }
    }

    private func transportButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
