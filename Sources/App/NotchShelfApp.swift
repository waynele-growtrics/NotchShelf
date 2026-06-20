import SwiftUI

@main
struct NotchShelfApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The only UI surface is the menu-bar item; the notch panel is created
        // imperatively in the AppDelegate.
        MenuBarExtra("NotchShelf", systemImage: "rectangle.topthird.inset.filled") {
            MenuContent(appDelegate: appDelegate)
        }
    }
}

/// Contents of the menu-bar dropdown.
private struct MenuContent: View {
    @ObservedObject var appDelegate: AppDelegate
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        Button("Clear Shelf") { appDelegate.shelf.clear() }
            .disabled(appDelegate.shelf.items.isEmpty)

        Toggle("Launch at Login", isOn: $launchAtLogin)
            .onChange(of: launchAtLogin) { newValue in
                LaunchAtLogin.set(newValue)
                launchAtLogin = LaunchAtLogin.isEnabled
            }

        Divider()

        Button("Quit NotchShelf") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
