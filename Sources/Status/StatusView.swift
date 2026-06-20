import SwiftUI

/// Battery + clock chip used inside the expanded panel.
struct StatusView: View {
    @ObservedObject var model: SystemStatusModel

    var body: some View {
        HStack(spacing: 12) {
            Label {
                Text(model.time)
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
            } icon: {
                Image(systemName: "clock")
            }

            if model.hasBattery {
                Label {
                    Text("\(model.batteryLevel)%")
                        .font(.system(size: 11, weight: .medium))
                        .monospacedDigit()
                } icon: {
                    Image(systemName: model.batterySymbol)
                        .foregroundStyle(batteryTint)
                }
            }
        }
        .labelStyle(.titleAndIcon)
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
    }

    private var batteryTint: Color {
        if model.isCharging { return .green }
        if model.batteryLevel <= 15 { return .red }
        return .secondary
    }
}

/// The tiny always-visible readout shown on the collapsed notch's right side.
struct CollapsedStatusView: View {
    @ObservedObject var status: SystemStatusModel
    @ObservedObject var nowPlaying: NowPlayingModel

    var body: some View {
        HStack(spacing: 6) {
            if nowPlaying.isPlaying {
                Image(systemName: "waveform")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.green)
            }
            if status.hasBattery {
                Image(systemName: status.batterySymbol)
                    .font(.system(size: 11))
                    .foregroundStyle(status.isCharging ? .green : .white.opacity(0.85))
            }
        }
    }
}
