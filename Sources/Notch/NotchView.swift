import SwiftUI
import UniformTypeIdentifiers

/// Root content hosted by the notch window. Renders the collapsed silhouette that
/// hugs the hardware notch and the expanded panel (now-playing • shelf/clipboard •
/// status), animating between them on hover or during a drag.
struct NotchView: View {
    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject var shelf: ShelfModel
    @ObservedObject var nowPlaying: NowPlayingModel
    @ObservedObject var status: SystemStatusModel
    @ObservedObject var clipboard: ClipboardModel
    @ObservedObject private var settings = Settings.shared
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    enum Tab { case files, clipboard }
    @State private var tab: Tab = .files

    var body: some View {
        // The window is a fixed size; the visible panel sizes itself inside and is
        // top-anchored. The controller toggles the window's `ignoresMouseEvents`
        // so that when collapsed every click passes through to the app underneath.
        ZStack(alignment: .top) {
            Color.clear.allowsHitTesting(false)
            panel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var accent: Color { settings.accent.color }

    private var panel: some View {
        VStack(spacing: 0) {
            if viewModel.isOpen {
                expandedContent
                    .padding(.top, viewModel.notchSize.height)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .transition(.opacity)
            } else {
                collapsedContent
            }
        }
        .frame(width: viewModel.currentSize.width, height: viewModel.currentSize.height)
        .background(NotchShape().fill(.black))
        .clipShape(NotchShape())
        .overlay {
            if viewModel.isDropTargeted {
                NotchShape().stroke(accent, lineWidth: 2)
            }
        }
        .contentShape(NotchShape())
        .onDrop(of: [.fileURL, .data], isTargeted: dropBinding) { providers in
            tab = .files
            shelf.accept(providers)
            return true
        }
        .animation(viewModel.animation, value: viewModel.isOpen)
    }

    private var dropBinding: Binding<Bool> {
        Binding(get: { viewModel.isDropTargeted },
                set: { viewModel.isDropTargeted = $0 })
    }

    // MARK: - Collapsed

    private var collapsedContent: some View {
        HStack(spacing: 0) {
            if !shelf.items.isEmpty {
                Text("\(shelf.items.count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.leading, 8)
            }
            Spacer(minLength: 0)
            CollapsedStatusView(status: status, nowPlaying: nowPlaying)
                .padding(.trailing, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Expanded

    private var expandedContent: some View {
        VStack(spacing: 8) {
            NowPlayingView(model: nowPlaying, accent: accent)
            if settings.showClipboard { tabBar }
            Divider().overlay(Color.white.opacity(0.12))
            middleSection
                .frame(maxHeight: .infinity)
                .clipped()
            bottomBar
        }
        .foregroundStyle(.white)
    }

    private var tabBar: some View {
        HStack(spacing: 6) {
            tabButton("Files", .files, count: shelf.items.count)
            tabButton("Clipboard", .clipboard, count: clipboard.items.count)
            Spacer()
        }
    }

    private func tabButton(_ title: String, _ value: Tab, count: Int) -> some View {
        Button { tab = value } label: {
            HStack(spacing: 4) {
                Text(title).font(.system(size: 10, weight: .semibold))
                if count > 0 {
                    Text("\(count)").font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Capsule().fill(.white.opacity(0.15)))
                }
            }
            .foregroundStyle(tab == value ? .white : .white.opacity(0.5))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(tab == value ? accent.opacity(0.35) : .clear))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var middleSection: some View {
        if settings.showClipboard && tab == .clipboard {
            ClipboardView(model: clipboard)
        } else {
            ShelfView(model: shelf, accent: accent)
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            StatusView(model: status)
            Spacer()
            if tab == .files && !shelf.items.isEmpty {
                Text(shelf.totalSizeString)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            settingsMenu
        }
    }

    /// In-panel settings + quit, so the app is controllable without hunting for
    /// the menu-bar icon (which can hide behind the notch).
    private var settingsMenu: some View {
        Menu {
            Button("Save All to Downloads") { shelf.saveAllToDownloads() }
                .disabled(shelf.items.isEmpty)
            Button(tab == .clipboard ? "Clear Clipboard History" : "Clear Shelf") {
                tab == .clipboard ? clipboard.clear() : shelf.clear()
            }
            Divider()
            Toggle("Launch at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { newValue in
                    LaunchAtLogin.set(newValue)
                    launchAtLogin = LaunchAtLogin.isEnabled
                }
            Button("Settings…") { SettingsWindow.show() }
            Divider()
            Button("Quit NotchShelf") { NSApplication.shared.terminate(nil) }
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .frame(width: 22)
    }
}
