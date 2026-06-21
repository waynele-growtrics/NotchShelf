import SwiftUI
import Combine
import Carbon.HIToolbox

/// Wires up the app on launch: becomes a background accessory (no Dock icon),
/// builds the shared models, and shows the notch panel.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let viewModel = NotchViewModel()
    let shelf = ShelfModel()
    let nowPlaying = NowPlayingModel()
    let status = SystemStatusModel()
    let clipboard = ClipboardModel()

    private var windowController: NotchWindowController?
    private var toggleHotKey: HotKey?
    private var expiryTimer: Timer?
    private var settingsObserver: AnyObject?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Background agent: no Dock icon, no app menu. (Also set via LSUIElement.)
        NSApp.setActivationPolicy(.accessory)

        windowController = NotchWindowController(
            viewModel: viewModel,
            shelf: shelf,
            nowPlaying: nowPlaying,
            status: status,
            clipboard: clipboard)

        // Surface the Automation consent prompt for the running media player so
        // Now Playing works on macOS 15.4+ (where MediaRemote is locked down).
        nowPlaying.requestPermission()

        configureHotKey()
        // React to the hotkey setting being toggled in Settings.
        settingsObserver = Settings.shared.$enableHotkey.sink { [weak self] _ in
            Task { @MainActor in self?.configureHotKey() }
        }

        // Periodically expire old unpinned shelf items.
        expiryTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.shelf.pruneExpired() }
        }
    }

    private func configureHotKey() {
        toggleHotKey?.unregister()
        toggleHotKey = nil
        guard Settings.shared.enableHotkey else { return }
        // ⌘⌥N toggles the panel.
        toggleHotKey = HotKey(keyCode: kVK_ANSI_N, modifiers: cmdKey | optionKey) { [weak self] in
            self?.windowController?.toggle()
        }
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}
