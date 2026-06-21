import SwiftUI
import Combine

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
        acceptsMouseMovedEvents = true
    }

    // Allow controls (buttons) to take clicks, but never become the main window or
    // activate the app.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Owns the notch panel and keeps it sized to *exactly* the visible panel: a
/// notch-sized strip when collapsed, the full panel when expanded. Because the
/// window never extends past what's drawn, clicks below the collapsed notch pass
/// straight through to whatever app is underneath.
@MainActor
final class NotchWindowController {
    private let panel: NotchPanel
    private let viewModel: NotchViewModel

    /// Screen-space rectangle of the notch hot-zone that opens the panel.
    private var hotZone: NSRect = .zero
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var cancellables: Set<AnyCancellable> = []

    init(viewModel: NotchViewModel,
         shelf: ShelfModel,
         nowPlaying: NowPlayingModel,
         status: SystemStatusModel,
         clipboard: ClipboardModel) {
        self.viewModel = viewModel

        let initial = NSRect(x: 0, y: 0, width: viewModel.expandedWidth, height: viewModel.expandedHeight)
        panel = NotchPanel(contentRect: initial)

        let root = NotchView(viewModel: viewModel, shelf: shelf, nowPlaying: nowPlaying,
                             status: status, clipboard: clipboard)
        let host = NSHostingView(rootView: root)
        host.sizingOptions = []
        host.translatesAutoresizingMaskIntoConstraints = true
        host.autoresizingMask = [.width, .height]
        host.frame = CGRect(origin: .zero, size: initial.size)
        panel.contentView = host

        // Collapsed by default: pass every click through to the app underneath.
        panel.ignoresMouseEvents = true

        positionWindow()
        panel.orderFrontRegardless()

        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)

        installMouseMonitors()

        // Only the visible panel should capture clicks: interactive when open,
        // fully click-through when collapsed. No window resizing (which triggers
        // an NSHostingView layout-loop crash) — we just gate mouse events.
        viewModel.$state.dropFirst().sink { [weak self] state in
            Task { @MainActor in self?.panel.ignoresMouseEvents = (state == .collapsed && self?.viewModel.isDropTargeted == false) }
        }.store(in: &cancellables)
        Settings.shared.$panelWidth.dropFirst().sink { [weak self] _ in
            Task { @MainActor in self?.positionWindow() }
        }.store(in: &cancellables)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
    }

    /// Drive expand/collapse from the cursor position. This works regardless of
    /// key-window state (SwiftUI `.onHover` does not on a background panel).
    private func installMouseMonitors() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            Task { @MainActor in self?.evaluateHover() }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            Task { @MainActor in self?.evaluateHover() }
            return event
        }
    }

    private func evaluateHover() {
        let mouse = NSEvent.mouseLocation
        if viewModel.isOpen {
            if !visiblePanelRect.insetBy(dx: -14, dy: -14).contains(mouse) {
                viewModel.close()
            }
        } else if hotZone.contains(mouse) {
            viewModel.open()
        }
    }

    @objc private func screensChanged() {
        Task { @MainActor in self.positionWindow() }
    }

    /// Place the fixed-size window at the top-center over the notch, and compute
    /// the notch hot-zone. The window stays this size; only `ignoresMouseEvents`
    /// and the SwiftUI content change between states.
    func positionWindow() {
        guard let screen = NSScreen.notchScreen else { return }
        let notch = screen.effectiveNotchRect
        viewModel.notchSize = CGSize(width: notch.width, height: notch.height)

        hotZone = NSRect(x: notch.minX - 6, y: notch.minY - 8,
                         width: notch.width + 12, height: notch.height + 8)

        let width = viewModel.expandedWidth
        let height = viewModel.expandedHeight
        let frame = NSRect(x: notch.midX - width / 2,
                           y: screen.frame.maxY - height,
                           width: width, height: height)
        panel.setFrame(frame, display: true)
    }

    /// The screen rect actually covered by the visible panel right now.
    private var visiblePanelRect: NSRect {
        let size = viewModel.currentSize
        return NSRect(x: panel.frame.midX - size.width / 2,
                      y: panel.frame.maxY - size.height,
                      width: size.width, height: size.height)
    }

    func toggle() { viewModel.isOpen ? viewModel.close() : viewModel.open() }
    func show() { panel.orderFrontRegardless() }
    func hide() { panel.orderOut(nil) }
}
