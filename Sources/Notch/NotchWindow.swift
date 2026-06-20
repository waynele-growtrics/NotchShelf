import SwiftUI

/// A borderless, non-activating panel that floats over the notch on every Space,
/// including over full-screen apps, and never steals focus from the active app.
final class NotchPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)

        isFloatingPanel = true
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        ignoresMouseEvents = false
        // Receive mouse-moved so SwiftUI .onHover tracking fires without activation.
        acceptsMouseMovedEvents = true
    }

    // Allow controls (buttons) to take clicks, but never become the main window or
    // activate the app.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Owns the notch panel, positions it over the active screen's notch, and keeps it
/// aligned as displays change.
@MainActor
final class NotchWindowController {
    private let panel: NotchPanel
    private let viewModel: NotchViewModel

    init(viewModel: NotchViewModel,
         shelf: ShelfModel,
         nowPlaying: NowPlayingModel,
         status: SystemStatusModel) {
        self.viewModel = viewModel

        let initial = NSRect(x: 0, y: 0, width: viewModel.expandedWidth, height: viewModel.expandedHeight)
        panel = NotchPanel(contentRect: initial)

        let root = NotchView(viewModel: viewModel, shelf: shelf, nowPlaying: nowPlaying, status: status)
        let host = NSHostingView(rootView: root)
        host.frame = initial
        panel.contentView = host

        reposition()
        panel.orderFrontRegardless()

        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func screensChanged() {
        Task { @MainActor in self.reposition() }
    }

    /// Size the panel to the active screen's notch and pin it to the top-center.
    func reposition() {
        guard let screen = NSScreen.notchScreen else { return }
        let notch = screen.effectiveNotchRect
        viewModel.notchSize = CGSize(width: notch.width, height: notch.height)

        let width = viewModel.expandedWidth
        let height = viewModel.expandedHeight
        let originX = notch.midX - width / 2
        let originY = screen.frame.maxY - height
        panel.setFrame(NSRect(x: originX, y: originY, width: width, height: height), display: true)
    }

    func show() { panel.orderFrontRegardless() }
    func hide() { panel.orderOut(nil) }
}
