import SwiftUI
import UniformTypeIdentifiers

/// One file held on the shelf. The canonical bytes live at `storageURL` inside our
/// own storage directory (we copy inbound files immediately, because the URLs we
/// receive from a drop are transient). Dragging an item out vends a *fresh* temp
/// copy each time so a receiver that moves rather than copies can't destroy our
/// stored original.
struct ShelfItem: Identifiable, Hashable, Sendable {
    let id: UUID
    let fileName: String
    let storageURL: URL
    let addedAt: Date
    let byteSize: Int64

    init(id: UUID = UUID(), fileName: String, storageURL: URL, addedAt: Date, byteSize: Int64) {
        self.id = id
        self.fileName = fileName
        self.storageURL = storageURL
        self.addedAt = addedAt
        self.byteSize = byteSize
    }

    /// The Finder icon for the stored file, sized for the shelf cell.
    var icon: NSImage {
        let image = NSWorkspace.shared.icon(forFile: storageURL.path)
        image.size = NSSize(width: 48, height: 48)
        return image
    }

    var humanSize: String {
        ByteCountFormatter.string(fromByteCount: byteSize, countStyle: .file)
    }
}

extension ShelfItem: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        // Export-only. `.data` content type lets any file kind drag out to Finder,
        // Mail, Slack, etc. We copy to a fresh temp dir per export and allow the
        // receiver to access it directly.
        FileRepresentation(exportedContentType: .data, shouldAllowToOpenInPlace: false) { item in
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent("NotchShelfExport", isDirectory: true)
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let dest = dir.appendingPathComponent(item.fileName)
            try FileManager.default.copyItem(at: item.storageURL, to: dest)
            return SentTransferredFile(dest, allowAccessingOriginalFile: true)
        }
        // A bare FileRepresentation is rejected by Finder/Slack on macOS 13/14;
        // also vending the URL as a proxy makes the drop accept reliably.
        ProxyRepresentation { item in item.storageURL }
    }
}
