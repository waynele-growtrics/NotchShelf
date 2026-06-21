import SwiftUI
import UniformTypeIdentifiers

/// The file shelf: a row of dropped files. Each cell drags back out to Finder or
/// any app; the whole strip is a drop target for adding more.
struct ShelfView: View {
    @ObservedObject var model: ShelfModel
    var accent: Color = .accentColor

    var body: some View {
        Group {
            if model.items.isEmpty {
                emptyState
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(model.items) { item in
                            ShelfItemCell(item: item, model: model, accent: accent)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(.secondary)
            Text("Drop files here")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A single draggable file cell.
private struct ShelfItemCell: View {
    let item: ShelfItem
    @ObservedObject var model: ShelfModel
    var accent: Color
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: item.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
            Text(item.fileName)
                .font(.system(size: 9))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 64)
                .foregroundStyle(.primary)
        }
        .frame(width: 72, height: 70)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering ? Color.white.opacity(0.12) : Color.white.opacity(0.05))
        )
        .overlay(alignment: .topLeading) {
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(accent)
                    .padding(3)
            }
        }
        .overlay(alignment: .topTrailing) {
            if isHovering {
                Button {
                    model.remove(item)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.white, .black.opacity(0.5))
                }
                .buttonStyle(.plain)
                .padding(2)
            }
        }
        .contentShape(Rectangle())
        .draggable(item)
        .onHover { isHovering = $0 }
        .help(item.fileName + " — " + item.humanSize)
        .contextMenu {
            Button("Open") { model.open(item) }
            Button("Reveal in Finder") { model.revealInFinder(item) }
            Button("Share…") { model.share(item) }
            Button(item.isPinned ? "Unpin" : "Pin") { model.togglePin(item) }
            Divider()
            Button("Remove", role: .destructive) { model.remove(item) }
        }
    }
}
