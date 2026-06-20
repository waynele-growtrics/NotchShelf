import ServiceManagement

/// Thin wrapper over `SMAppService.mainApp` (macOS 13+). The service's own status
/// is the source of truth — never trust a persisted flag, because the user can
/// change it in System Settings ▸ General ▸ Login Items.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func set(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("NotchShelf: launch-at-login change failed: \(error.localizedDescription)")
        }
    }

    static func toggle() { set(!isEnabled) }
}
