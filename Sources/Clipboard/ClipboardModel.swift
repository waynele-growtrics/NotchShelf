import SwiftUI
import UniformTypeIdentifiers

/// One entry in the clipboard history — text or an image.
struct ClipItem: Identifiable, Hashable, Sendable {
    enum Kind: Hashable { case text(String), image }
    let id: UUID
    let kind: Kind
    let preview: String          // short label
    let date: Date
    let imagePNG: Data?          // populated for image items

    var isImage: Bool { if case .image = kind { return true }; return false }
    var text: String? { if case let .text(s) = kind { return s }; return nil }
}

extension ClipItem: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        // Text items export as plain text; image items export PNG bytes.
        DataRepresentation(exportedContentType: .png) { item in item.imagePNG ?? Data() }
            .suggestedFileName("clipboard.png")
        ProxyRepresentation { item in item.text ?? item.preview }
    }
}

/// Watches the system pasteboard and keeps a short in-memory history (never
/// written to disk, for privacy). Items copied by password managers (marked
/// concealed/transient) are ignored.
@MainActor
final class ClipboardModel: ObservableObject {
    @Published private(set) var items: [ClipItem] = []

    private let maxItems = 20
    private var lastChangeCount = NSPasteboard.general.changeCount
    private var timer: Timer?

    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    deinit { timer?.invalidate() }

    private func poll() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        // Respect privacy markers used by password managers.
        let concealed = ["org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType"]
        if let types = pb.types, types.contains(where: { concealed.contains($0.rawValue) }) { return }

        if let image = NSImage(pasteboard: pb),
           let png = image.pngData() {
            push(ClipItem(id: UUID(), kind: .image, preview: "Image", date: Date(), imagePNG: png))
        } else if let str = pb.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !str.isEmpty {
            push(ClipItem(id: UUID(), kind: .text(str),
                          preview: String(str.prefix(120)), date: Date(), imagePNG: nil))
        }
    }

    private func push(_ item: ClipItem) {
        // Drop a consecutive duplicate of the most recent entry.
        if let first = items.first {
            if first.text != nil, first.text == item.text { return }
            if first.isImage, item.isImage, first.imagePNG == item.imagePNG { return }
        }
        items.insert(item, at: 0)
        if items.count > maxItems { items.removeLast(items.count - maxItems) }
    }

    /// Put an item back on the pasteboard (so the next paste uses it).
    func copyToPasteboard(_ item: ClipItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        if let text = item.text {
            pb.setString(text, forType: .string)
        } else if let png = item.imagePNG, let image = NSImage(data: png) {
            pb.writeObjects([image])
        }
        lastChangeCount = pb.changeCount   // don't re-capture our own write
    }

    func remove(_ item: ClipItem) { items.removeAll { $0.id == item.id } }
    func clear() { items.removeAll() }
}

extension NSImage {
    /// PNG-encode the image (used for clipboard image items and drag-out).
    func pngData() -> Data? {
        guard let tiff = tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
