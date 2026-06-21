import SwiftUI
import Combine
import Carbon

/// Reads "Now Playing" from media apps via AppleScript.
///
/// Background: macOS 15.4 added entitlement checks to `mediaremoted`, so the
/// private MediaRemote framework no longer returns data to third-party apps. The
/// reliable, dependency-free path for the common players is AppleScript against
/// Music.app / Spotify (a universal solution would need the perl-based
/// `mediaremote-adapter`).
///
/// We detect the *running* player in-process with `NSWorkspace` (so we never need
/// to control `System Events`, and never accidentally launch a player), then send
/// AppleScript only to that app. The first read needs the user to grant Automation
/// permission — we request it explicitly and surface `needsPermission` so the UI
/// can guide the user instead of silently showing "nothing playing".
@MainActor
final class NowPlayingModel: ObservableObject {

    @Published var title: String = ""
    @Published var artist: String = ""
    @Published var album: String = ""
    @Published var artwork: NSImage?
    @Published var isPlaying: Bool = false
    @Published var elapsed: Double = 0      // seconds
    @Published var duration: Double = 0      // seconds
    /// True when a player is running but macOS hasn't granted Automation access.
    @Published var needsPermission: Bool = false

    var progress: Double { duration > 0 ? min(max(elapsed / duration, 0), 1) : 0 }

    var hasTrack: Bool { !title.isEmpty }

    enum Source: String, CaseIterable {
        case music, spotify
        var bundleID: String { self == .music ? "com.apple.Music" : "com.spotify.client" }
        var appName: String { self == .music ? "Music" : "Spotify" }
    }
    private var source: Source?

    private var timer: Timer?
    private static let queue = DispatchQueue(label: "com.notchshelf.applescript")

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    deinit { timer?.invalidate() }

    // MARK: - Reading

    func refresh() {
        // Which supported player is currently running? (in-process, no AppleScript)
        let running = NSWorkspace.shared.runningApplications.compactMap { app -> Source? in
            guard let id = app.bundleIdentifier else { return nil }
            return Source.allCases.first { $0.bundleID == id }
        }
        guard let player = running.first else {
            apply(Info())                 // nothing running
            return
        }
        Self.queue.async {
            let info = Self.read(player)
            Task { @MainActor in self.apply(info) }
        }
    }

    private struct Info {
        var source: Source?
        var title = "", artist = "", album = ""
        var isPlaying = false
        var elapsed = 0.0, duration = 0.0
        var denied = false
    }

    private func apply(_ info: Info) {
        let trackChanged = (info.title != title) || (info.source != source)
        source = info.source
        title = info.title
        artist = info.artist
        album = info.album
        isPlaying = info.isPlaying
        elapsed = info.elapsed
        duration = info.duration
        needsPermission = info.denied
        // Only refetch the (static) app icon when the track/source actually changes.
        if trackChanged { artwork = info.source.flatMap { Self.appIcon(for: $0) } }
    }

    private nonisolated static func read(_ player: Source) -> Info {
        // Coerce position/duration to integers in-script: a plain `as text` of a
        // real uses the system locale's decimal separator (e.g. a comma), which
        // would break `Double(...)` parsing on non-US locales.
        let script = """
        tell application "\(player.appName)"
            set s to player state as text
            if s is "stopped" then return ""
            set p to (player position) as integer
            set d to (duration of current track) as integer
            return s & "\t" & (name of current track) & "\t" & (artist of current track) & "\t" & (album of current track) & "\t" & (p as text) & "\t" & (d as text)
        end tell
        """
        var denied = false
        guard let raw = runAppleScript(script, denied: &denied) else {
            return Info(source: nil, denied: denied)
        }
        if raw.isEmpty { return Info() }       // running but stopped / between tracks
        let p = raw.components(separatedBy: "\t")
        guard p.count >= 6 else { return Info() }
        let elapsed = Double(p[4]) ?? 0
        // Spotify reports track duration in milliseconds; Music in seconds.
        var duration = Double(p[5]) ?? 0
        if player == .spotify { duration /= 1000 }
        return Info(source: player, title: p[1], artist: p[2], album: p[3],
                    isPlaying: p[0] == "playing", elapsed: elapsed, duration: duration)
    }

    // MARK: - Commands

    func togglePlayPause() { command("playpause"); optimisticToggle() }
    func next() { command("next track") }
    func previous() { command("previous track") }

    /// Seek to a fraction (0...1) of the current track.
    func seek(toFraction f: Double) {
        guard duration > 0, let app = source?.appName else { return }
        let pos = Int((min(max(f, 0), 1) * duration).rounded())
        elapsed = Double(pos)
        Self.queue.async {
            var ignored = false
            _ = NowPlayingModel.runAppleScript("tell application \"\(app)\" to set player position to \(pos)", denied: &ignored)
        }
    }

    /// Bring the playing app to the front (used when clicking the artwork).
    func activatePlayer() {
        guard let id = source?.bundleID,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    private func optimisticToggle() {
        isPlaying.toggle()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.refresh() }
    }

    private func command(_ verb: String) {
        guard let app = source?.appName else { return }
        Self.queue.async {
            var ignored = false
            _ = NowPlayingModel.runAppleScript("tell application \"\(app)\" to \(verb)", denied: &ignored)
        }
    }

    // MARK: - Permission

    /// Explicitly ask macOS for Automation access to whichever player is running,
    /// surfacing the system prompt. Safe to call repeatedly.
    func requestPermission() {
        let running = NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier }
        let targets = Source.allCases.filter { running.contains($0.bundleID) }
        Self.queue.async {
            for t in targets { _ = Self.determinePermission(bundleID: t.bundleID, ask: true) }
            Task { @MainActor in self.refresh() }
        }
    }

    func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Helpers

    private nonisolated static func runAppleScript(_ source: String, denied: inout Bool) -> String? {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return nil }
        let descriptor = script.executeAndReturnError(&error)
        if let error, let code = error[NSAppleScript.errorNumber] as? Int {
            // -1743 = errAEEventNotPermitted, -1744 = would require consent.
            denied = (code == -1743 || code == -1744)
            return nil
        }
        return descriptor.stringValue
    }

    /// Wraps `AEDeterminePermissionToAutomateTarget`. Returns the OSStatus
    /// (`noErr` = granted). With `ask` true the system shows the consent prompt.
    @discardableResult
    private nonisolated static func determinePermission(bundleID: String, ask: Bool) -> OSStatus {
        var target = AEAddressDesc()
        let data = Data(bundleID.utf8)
        let status = data.withUnsafeBytes { buf in
            OSStatus(AECreateDesc(typeApplicationBundleID, buf.baseAddress, data.count, &target))
        }
        guard status == noErr else { return status }
        defer { AEDisposeDesc(&target) }
        return AEDeterminePermissionToAutomateTarget(&target, typeWildCard, typeWildCard, ask)
    }

    private nonisolated static func appIcon(for source: Source) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: source.bundleID) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 38, height: 38)
        return icon
    }
}
