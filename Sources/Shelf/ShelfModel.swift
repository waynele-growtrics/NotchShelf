import SwiftUI
import UniformTypeIdentifiers

/// Owns the files currently on the shelf and the on-disk storage backing them.
@MainActor
final class ShelfModel: ObservableObject {
    @Published private(set) var items: [ShelfItem] = []

    /// Root of our private storage. Files dropped onto the shelf are copied here so
    /// they survive even if the source is moved or deleted.
    private let storageRoot: URL
    private let pinsKey = "shelfPinnedIDs"
    private var pinnedIDs: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: pinsKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: pinsKey) }
    }

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        storageRoot = base.appendingPathComponent("NotchShelf/Shelf", isDirectory: true)
        try? FileManager.default.createDirectory(at: storageRoot, withIntermediateDirectories: true)
        reload()
        pruneExpired()
    }

    /// Total size of everything on the shelf, formatted for display.
    var totalSizeString: String {
        ByteCountFormatter.string(fromByteCount: items.reduce(0) { $0 + $1.byteSize }, countStyle: .file)
    }

    /// Rebuild the in-memory list from whatever is already on disk (survives relaunch).
    func reload() {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: storageRoot,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]) else { return }

        items = entries.compactMap { url -> ShelfItem? in
            // Each item lives in its own UUID directory holding a single file.
            guard let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory, isDir,
                  let inner = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil).first
            else { return nil }
            let attrs = try? inner.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
            let id = url.lastPathComponent
            return ShelfItem(
                id: UUID(uuidString: id) ?? UUID(),
                fileName: inner.lastPathComponent,
                storageURL: inner,
                addedAt: attrs?.contentModificationDate ?? Date(),
                byteSize: Int64(attrs?.fileSize ?? 0),
                isPinned: pinnedIDs.contains(id))
        }
        .sorted { ($0.isPinned ? 1 : 0, $0.addedAt) > ($1.isPinned ? 1 : 0, $1.addedAt) }
    }

    /// Accept a batch of dropped item providers. Runs the blocking extraction off
    /// the main actor, then re-publishes on the main actor.
    func accept(_ providers: [NSItemProvider]) {
        Task.detached(priority: .userInitiated) {
            var copied: [URL] = []
            for provider in providers {
                if let url = await Self.resolveFileURL(provider) {
                    copied.append(url)
                }
            }
            await self.ingest(copied)
        }
    }

    /// Copy resolved source URLs into our storage and publish the new items.
    private func ingest(_ sourceURLs: [URL]) {
        let fm = FileManager.default
        var added: [ShelfItem] = []
        for src in sourceURLs {
            let id = UUID()
            let dir = storageRoot.appendingPathComponent(id.uuidString, isDirectory: true)
            let dest = dir.appendingPathComponent(src.lastPathComponent)
            do {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
                if fm.fileExists(atPath: dest.path) { try? fm.removeItem(at: dest) }
                try fm.copyItem(at: src, to: dest)
                let attrs = try? dest.resourceValues(forKeys: [.fileSizeKey])
                added.append(ShelfItem(id: id, fileName: src.lastPathComponent, storageURL: dest,
                                       addedAt: Date(), byteSize: Int64(attrs?.fileSize ?? 0)))
            } catch {
                try? fm.removeItem(at: dir)
            }
        }
        guard !added.isEmpty else { return }
        items = (added + items).sorted { ($0.isPinned ? 1 : 0, $0.addedAt) > ($1.isPinned ? 1 : 0, $1.addedAt) }
    }

    func remove(_ item: ShelfItem) {
        let dir = storageRoot.appendingPathComponent(item.id.uuidString, isDirectory: true)
        try? FileManager.default.removeItem(at: dir)
        pinnedIDs.remove(item.id.uuidString)
        items.removeAll { $0.id == item.id }
    }

    /// Clear everything except pinned items.
    func clear() {
        for item in items where !item.isPinned { remove(item) }
    }

    func togglePin(_ item: ShelfItem) {
        var pins = pinnedIDs
        let key = item.id.uuidString
        if pins.contains(key) { pins.remove(key) } else { pins.insert(key) }
        pinnedIDs = pins
        reload()
    }

    /// Copy every shelf item into ~/Downloads (de-duplicating names).
    func saveAllToDownloads() {
        guard let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else { return }
        let fm = FileManager.default
        for item in items {
            var dest = downloads.appendingPathComponent(item.fileName)
            var n = 1
            while fm.fileExists(atPath: dest.path) {
                let base = (item.fileName as NSString).deletingPathExtension
                let ext = (item.fileName as NSString).pathExtension
                let name = ext.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(ext)"
                dest = downloads.appendingPathComponent(name)
                n += 1
            }
            try? fm.copyItem(at: item.storageURL, to: dest)
        }
        NSWorkspace.shared.activateFileViewerSelecting([downloads])
    }

    /// Remove unpinned items older than the configured expiry window.
    func pruneExpired() {
        let hours = Settings.shared.autoExpiryHours
        guard hours > 0 else { return }
        let cutoff = Date().addingTimeInterval(-Double(hours) * 3600)
        for item in items where !item.isPinned && item.addedAt < cutoff { remove(item) }
    }

    /// Present the macOS share sheet (incl. AirDrop) for an item, anchored to the
    /// notch panel.
    func share(_ item: ShelfItem) {
        guard let view = NSApp.windows.first(where: { $0 is NotchPanel })?.contentView else { return }
        let picker = NSSharingServicePicker(items: [item.storageURL])
        picker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
    }

    func revealInFinder(_ item: ShelfItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.storageURL])
    }

    func open(_ item: ShelfItem) {
        NSWorkspace.shared.open(item.storageURL)
    }

    /// Resolve a dropped item into a stable staging URL we own. The URLs handed to
    /// these completion blocks are transient (file-reference / in-place temp URLs),
    /// so we copy to staging *inside the block* before returning. Tries the reliable
    /// `loadObject(ofClass: URL.self)` first, then an in-place file representation.
    private static func resolveFileURL(_ provider: NSItemProvider) async -> URL? {
        if let staged = await withCheckedContinuation({ (cont: CheckedContinuation<URL?, Never>) in
            guard provider.canLoadObject(ofClass: URL.self) else { cont.resume(returning: nil); return }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                cont.resume(returning: url.flatMap { $0.isFileURL ? Self.stage($0) : nil })
            }
        }) {
            return staged
        }
        // Fallback: in-place file representation (URL valid only within the block).
        return await withCheckedContinuation { (cont: CheckedContinuation<URL?, Never>) in
            provider.loadInPlaceFileRepresentation(forTypeIdentifier: UTType.data.identifier) { url, _, _ in
                cont.resume(returning: url.flatMap { Self.stage($0) })
            }
        }
    }

    /// Copy a transient source URL into a private staging directory and return the
    /// copy. Returns `nil` on failure.
    private static func stage(_ src: URL) -> URL? {
        let fm = FileManager.default
        let needsScope = src.startAccessingSecurityScopedResource()
        defer { if needsScope { src.stopAccessingSecurityScopedResource() } }
        let dir = fm.temporaryDirectory
            .appendingPathComponent("NotchShelfStaging", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let dest = dir.appendingPathComponent(src.lastPathComponent)
        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            try fm.copyItem(at: src, to: dest)
            return dest
        } catch {
            return nil
        }
    }
}
