import SwiftUI

/// Horizontal strip of recent clipboard entries. Click to re-copy, drag out to
/// paste elsewhere, hover for a remove button.
struct ClipboardView: View {
    @ObservedObject var model: ClipboardModel

    var body: some View {
        Group {
            if model.items.isEmpty {
                empty
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(model.items) { item in
                            ClipCell(item: item, model: model)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var empty: some View {
        VStack(spacing: 6) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
            Text("Copied text & images appear here")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ClipCell: View {
    let item: ClipItem
    @ObservedObject var model: ClipboardModel
    @State private var hover = false
    @State private var justCopied = false

    var body: some View {
        Button {
            model.copyToPasteboard(item)
            justCopied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { justCopied = false }
        } label: {
            content
                .frame(width: 92, height: 70)
                .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(hover ? 0.12 : 0.05)))
                .overlay(alignment: .topTrailing) {
                    if hover {
                        Button { model.remove(item) } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.white, .black.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                        .padding(2)
                    }
                }
                .overlay(alignment: .bottom) {
                    if justCopied {
                        Text("Copied")
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(.green))
                            .padding(.bottom, 4)
                    }
                }
        }
        .buttonStyle(.plain)
        .draggable(item)
        .onHover { hover = $0 }
    }

    @ViewBuilder private var content: some View {
        if item.isImage, let png = item.imagePNG, let img = NSImage(data: png) {
            Image(nsImage: img)
                .resizable().aspectRatio(contentMode: .fill)
                .frame(width: 84, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            VStack(spacing: 4) {
                Image(systemName: "text.alignleft").font(.system(size: 14)).foregroundStyle(.secondary)
                Text(item.preview)
                    .font(.system(size: 9))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 6)
            }
        }
    }
}
