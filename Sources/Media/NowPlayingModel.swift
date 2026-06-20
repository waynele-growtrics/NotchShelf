import SwiftUI
import Combine

/// Reads "Now Playing" via the private MediaRemote framework, loaded at runtime so
/// the app still builds and runs if the symbols are unavailable. Apple restricted
/// these APIs on recent macOS releases, so this is strictly best-effort: when no
/// data is returned the UI shows an idle state. No private symbols are linked at
/// build time — everything is resolved with `dlsym`.
@MainActor
final class NowPlayingModel: ObservableObject {

    @Published var title: String = ""
    @Published var artist: String = ""
    @Published var album: String = ""
    @Published var artwork: NSImage?
    @Published var isPlaying: Bool = false

    var hasTrack: Bool { !title.isEmpty }

    // MARK: - Private MediaRemote bindings

    private typealias GetInfoFn = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
    private typealias RegisterFn = @convention(c) (DispatchQueue) -> Void
    private typealias SendCommandFn = @convention(c) (Int, [String: Any]?) -> Bool

    private var getInfo: GetInfoFn?
    private var sendCommand: SendCommandFn?
    private var handle: UnsafeMutableRawPointer?

    // MediaRemote command codes.
    private enum Command: Int { case play = 0, pause = 1, togglePlayPause = 2, next = 4, previous = 5 }

    init() {
        loadFramework()
        refresh()
    }

    deinit {
        if let handle { dlclose(handle) }
    }

    private func loadFramework() {
        let path = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
        guard let handle = dlopen(path, RTLD_NOW) else { return }
        self.handle = handle

        if let sym = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") {
            getInfo = unsafeBitCast(sym, to: GetInfoFn.self)
        }
        if let sym = dlsym(handle, "MRMediaRemoteSendCommand") {
            sendCommand = unsafeBitCast(sym, to: SendCommandFn.self)
        }
        if let sym = dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications") {
            let register = unsafeBitCast(sym, to: RegisterFn.self)
            register(.main)
            // Refresh whenever the system broadcasts a now-playing change.
            for name in [
                "kMRMediaRemoteNowPlayingInfoDidChangeNotification",
                "kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification",
            ] {
                DistributedNotificationCenter.default().addObserver(
                    forName: Notification.Name(name), object: nil, queue: .main
                ) { [weak self] _ in
                    Task { @MainActor in self?.refresh() }
                }
            }
        }
    }

    // MARK: - Reading state

    func refresh() {
        guard let getInfo else { return }
        getInfo(.main) { [weak self] info in
            Task { @MainActor in self?.apply(info) }
        }
    }

    private func apply(_ info: [String: Any]) {
        title = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? ""
        artist = info["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? ""
        album = info["kMRMediaRemoteNowPlayingInfoAlbum"] as? String ?? ""
        if let rate = info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double {
            isPlaying = rate > 0
        }
        if let data = info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data {
            artwork = NSImage(data: data)
        } else if title.isEmpty {
            artwork = nil
        }
    }

    // MARK: - Commands

    func togglePlayPause() { send(.togglePlayPause); isPlaying.toggle() }
    func next() { send(.next) }
    func previous() { send(.previous) }

    private func send(_ command: Command) {
        _ = sendCommand?(command.rawValue, nil)
        // Give the player a beat to update, then re-read.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.refresh() }
    }
}
