import SwiftUI
import UniformTypeIdentifiers

/// Root content hosted by the notch window. Renders the collapsed silhouette that
/// hugs the hardware notch and the expanded panel (now-playing • shelf • status),
/// animating between them on hover or during a drag.
struct NotchView: View {
    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject var shelf: ShelfModel
    @ObservedObject var nowPlaying: NowPlayingModel
    @ObservedObject var status: SystemStatusModel
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        ZStack(alignment: .top) {
            // Full-window transparent layer; click-through so the rest of the
            // screen stays interactive when the panel is collapsed.
            Color.clear.allowsHitTesting(false)

            panel
        }
        .frame(width: viewModel.expandedWidth, height: viewModel.expandedHeight, alignment: .top)
    }

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
                NotchShape()
                    .stroke(Color.accentColor, lineWidth: 2)
            }
        }
        .contentShape(NotchShape())
        .onDrop(of: [.fileURL, .data], isTargeted: dropBinding) { providers in
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
        VStack(spacing: 10) {
            NowPlayingView(model: nowPlaying)
            Divider().overlay(Color.white.opacity(0.12))
            ShelfView(model: shelf)
                .frame(maxHeight: .infinity)
            HStack(spacing: 12) {
                StatusView(model: status)
                Spacer()
                if !shelf.items.isEmpty {
                    Button {
                        shelf.clear()
                    } label: {
                        Label("Clear", systemImage: "trash")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                settingsMenu
            }
        }
        .foregroundStyle(.white)
    }

    /// In-panel settings + quit, so the app is controllable without hunting for
    /// the menu-bar icon (which can hide behind the notch).
    private var settingsMenu: some View {
        Menu {
            Toggle("Launch at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { newValue in
                    LaunchAtLogin.set(newValue)
                    launchAtLogin = LaunchAtLogin.isEnabled
                }
            Button("Clear Shelf") { shelf.clear() }
                .disabled(shelf.items.isEmpty)
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
