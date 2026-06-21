import SwiftUI

/// A standalone preferences window (the app is otherwise window-less). Showing it
/// temporarily promotes the app to a regular app so the window can take focus;
/// closing it returns to the background-accessory state.
@MainActor
enum SettingsWindow {
    private static var window: NSWindow?

    static func show() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }
        let hosting = NSHostingController(rootView: SettingsView())
        let win = NSWindow(contentViewController: hosting)
        win.title = "NotchShelf Settings"
        win.styleMask = [.titled, .closable]
        win.isReleasedWhenClosed = false
        win.setContentSize(NSSize(width: 420, height: 460))
        win.center()
        window = win

        // Return to accessory mode when the window closes.
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification,
                                               object: win, queue: .main) { _ in
            Task { @MainActor in NSApp.setActivationPolicy(.accessory) }
        }
        win.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    @ObservedObject private var settings = Settings.shared
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        Form {
            Section("Appearance") {
                HStack {
                    Text("Panel width")
                    Slider(value: $settings.panelWidth, in: 360...560, step: 10)
                    Text("\(Int(settings.panelWidth))")
                        .monospacedDigit().frame(width: 34, alignment: .trailing)
                }
                Picker("Accent", selection: $settings.accent) {
                    ForEach(AccentColor.allCases) { c in
                        HStack { Circle().fill(c.color).frame(width: 10, height: 10); Text(c.label) }.tag(c)
                    }
                }
            }

            Section("Sections") {
                Toggle("Show clipboard history", isOn: $settings.showClipboard)
            }

            Section("Shelf") {
                Picker("Auto-clear unpinned files", selection: $settings.autoExpiryHours) {
                    Text("Never").tag(0)
                    Text("After 1 hour").tag(1)
                    Text("After 6 hours").tag(6)
                    Text("After 24 hours").tag(24)
                }
            }

            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { v in
                        LaunchAtLogin.set(v); launchAtLogin = LaunchAtLogin.isEnabled
                    }
                Toggle("Toggle panel with ⌘⌥N", isOn: $settings.enableHotkey)
            }

            Section {
                HStack {
                    Text("NotchShelf \(Bundle.main.shortVersion)")
                        .foregroundStyle(.secondary).font(.caption)
                    Spacer()
                    Button("Quit") { NSApplication.shared.terminate(nil) }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 460)
    }
}

extension Bundle {
    var shortVersion: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }
}
