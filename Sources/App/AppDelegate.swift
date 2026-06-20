import SwiftUI

/// Wires up the app on launch: becomes a background accessory (no Dock icon),
/// builds the shared models, and shows the notch panel.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let viewModel = NotchViewModel()
    let shelf = ShelfModel()
    let nowPlaying = NowPlayingModel()
    let status = SystemStatusModel()

    private var windowController: NotchWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Background agent: no Dock icon, no app menu. (Also set via LSUIElement.)
        NSApp.setActivationPolicy(.accessory)

        windowController = NotchWindowController(
            viewModel: viewModel,
            shelf: shelf,
            nowPlaying: nowPlaying,
            status: status)
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}
