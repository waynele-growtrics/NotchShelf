import SwiftUI
import Combine

/// User preferences, backed by `UserDefaults`. A single shared instance is read
/// by the views and the window controller (which reacts to `panelWidth`).
@MainActor
final class Settings: ObservableObject {
    static let shared = Settings()

    private let defaults = UserDefaults.standard

    @Published var panelWidth: Double { didSet { defaults.set(panelWidth, forKey: Keys.panelWidth) } }
    @Published var accent: AccentColor { didSet { defaults.set(accent.rawValue, forKey: Keys.accent) } }
    @Published var showClipboard: Bool { didSet { defaults.set(showClipboard, forKey: Keys.showClipboard) } }
    /// Hours after which unpinned shelf items are auto-removed. 0 disables expiry.
    @Published var autoExpiryHours: Int { didSet { defaults.set(autoExpiryHours, forKey: Keys.autoExpiry) } }
    @Published var enableHotkey: Bool { didSet { defaults.set(enableHotkey, forKey: Keys.hotkey) } }

    private init() {
        panelWidth = defaults.object(forKey: Keys.panelWidth) as? Double ?? 420
        accent = AccentColor(rawValue: defaults.string(forKey: Keys.accent) ?? "") ?? .blue
        showClipboard = defaults.object(forKey: Keys.showClipboard) as? Bool ?? true
        autoExpiryHours = defaults.object(forKey: Keys.autoExpiry) as? Int ?? 0
        enableHotkey = defaults.object(forKey: Keys.hotkey) as? Bool ?? true
    }

    private enum Keys {
        static let panelWidth = "panelWidth"
        static let accent = "accent"
        static let showClipboard = "showClipboard"
        static let autoExpiry = "autoExpiryHours"
        static let hotkey = "enableHotkey"
    }
}

enum AccentColor: String, CaseIterable, Identifiable {
    case blue, purple, pink, green, orange, graphite
    var id: String { rawValue }

    var color: Color {
        switch self {
        case .blue: return Color(red: 0.15, green: 0.5, blue: 0.96)
        case .purple: return Color(red: 0.49, green: 0.35, blue: 0.96)
        case .pink: return Color(red: 0.93, green: 0.28, blue: 0.6)
        case .green: return Color(red: 0.2, green: 0.78, blue: 0.45)
        case .orange: return Color(red: 0.98, green: 0.55, blue: 0.18)
        case .graphite: return Color(white: 0.7)
        }
    }
    var label: String { rawValue.capitalized }
}
