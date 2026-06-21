import SwiftUI

/// Compact now-playing strip: artwork, track/artist, transport controls, and a
/// seekable progress bar. Falls back to an idle row when nothing is playing (or
/// the private API is unavailable on this macOS version).
struct NowPlayingView: View {
    @ObservedObject var model: NowPlayingModel
    var accent: Color = .accentColor

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                artwork
                VStack(alignment: .leading, spacing: 1) {
                    Text(primaryText)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    Text(secondaryText)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                if model.needsPermission {
                    Button("Enable") { model.requestPermission(); model.openAutomationSettings() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                } else if model.hasTrack {
                    controls
                }
            }
            if model.hasTrack && model.duration > 0 {
                ProgressBar(progress: model.progress, accent: accent) { model.seek(toFraction: $0) }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var primaryText: String {
        if model.hasTrack { return model.title }
        return model.needsPermission ? "Now Playing needs permission" : "Nothing playing"
    }

    private var secondaryText: String {
        if model.hasTrack { return model.artist }
        return model.needsPermission ? "Click Enable, then allow Automation" : "Start a track to see it here"
    }

    private var artwork: some View {
        Button { model.activatePlayer() } label: {
            Group {
                if let art = model.artwork {
                    Image(nsImage: art).resizable().aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        Color.white.opacity(0.08)
                        Image(systemName: "music.note").font(.system(size: 16)).foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 38, height: 38)
            .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .disabled(!model.hasTrack)
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

/// A thin seek bar; click or drag anywhere to scrub.
private struct ProgressBar: View {
    let progress: Double
    let accent: Color
    let onSeek: (Double) -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.15))
                Capsule().fill(accent)
                    .frame(width: max(0, geo.size.width * progress))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onEnded { value in
                    onSeek(value.location.x / geo.size.width)
                }
            )
        }
        .frame(height: 4)
    }
}
