import SwiftUI
import Combine
import IOKit.ps

/// Lightweight system status shown in the collapsed and expanded notch: battery
/// level, charging state, and the current time. Battery is read via the public
/// IOKit Power Sources API — no private symbols, no entitlements.
@MainActor
final class SystemStatusModel: ObservableObject {

    @Published var batteryLevel: Int = 100      // 0–100, -1 when unavailable (desktop)
    @Published var isCharging: Bool = false
    @Published var isPluggedIn: Bool = false
    @Published var hasBattery: Bool = true
    @Published var time: String = ""

    private var timer: Timer?
    private let clock: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm"
        return f
    }()

    init() {
        refresh()
        // One timer drives both the clock and a periodic battery poll.
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    deinit { timer?.invalidate() }

    func refresh() {
        time = clock.string(from: Date())
        readBattery()
    }

    private func readBattery() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any]
        else {
            hasBattery = false
            batteryLevel = -1
            return
        }

        if let capacity = desc[kIOPSCurrentCapacityKey] as? Int,
           let max = desc[kIOPSMaxCapacityKey] as? Int, max > 0 {
            hasBattery = true
            batteryLevel = Int((Double(capacity) / Double(max) * 100).rounded())
        }
        if let state = desc[kIOPSPowerSourceStateKey] as? String {
            isPluggedIn = (state == kIOPSACPowerValue)
        }
        isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false
    }

    /// SF Symbol that best represents the current battery state.
    var batterySymbol: String {
        guard hasBattery else { return "bolt.fill" }
        if isCharging { return "battery.100.bolt" }
        switch batteryLevel {
        case ..<13: return "battery.0"
        case ..<38: return "battery.25"
        case ..<63: return "battery.50"
        case ..<88: return "battery.75"
        default: return "battery.100"
        }
    }
}
