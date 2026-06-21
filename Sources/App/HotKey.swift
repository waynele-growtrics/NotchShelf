import Carbon.HIToolbox

/// A system-wide hotkey via Carbon `RegisterEventHotKey` (no Accessibility
/// permission required, unlike `NSEvent` global key monitors).
final class HotKey {
    private var ref: EventHotKeyRef?
    private let id: UInt32

    private static var actions: [UInt32: () -> Void] = [:]
    private static var nextID: UInt32 = 1
    private static var handlerInstalled = false

    /// `keyCode` is a Carbon virtual key (e.g. `kVK_ANSI_N`); `modifiers` combine
    /// `cmdKey`, `optionKey`, etc.
    init(keyCode: Int, modifiers: Int, action: @escaping () -> Void) {
        id = HotKey.nextID
        HotKey.nextID += 1
        HotKey.installHandlerIfNeeded()
        HotKey.actions[id] = action

        var hotKeyRef: EventHotKeyRef?
        let hkID = EventHotKeyID(signature: OSType(0x4E534846), id: id)   // 'NSHF'
        RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), hkID,
                            GetApplicationEventTarget(), 0, &hotKeyRef)
        ref = hotKeyRef
    }

    deinit { unregister() }

    func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
        HotKey.actions[id] = nil
    }

    private static func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var hkID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            if let action = HotKey.actions[hkID.id] {
                DispatchQueue.main.async { action() }
            }
            return noErr
        }, 1, &spec, nil, nil)
    }
}
