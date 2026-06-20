import AppKit

/// Notch geometry helpers. The auxiliary-area APIs ship with macOS 12 (the first
/// notched MacBooks); `safeAreaInsets` arrived in the same release. We read every
/// value at runtime — notch height varies by model (~32–37pt) and must never be
/// hardcoded.
extension NSScreen {

    /// True when this display has a physical camera-housing notch.
    var hasNotch: Bool {
        if safeAreaInsets.top > 0 { return true }
        return auxiliaryTopLeftArea != nil && auxiliaryTopRightArea != nil
    }

    /// The rectangle of the physical notch in this screen's coordinate space
    /// (AppKit points, bottom-left origin). `nil` on notch-less displays.
    var notchRect: NSRect? {
        guard let left = auxiliaryTopLeftArea,
              let right = auxiliaryTopRightArea else { return nil }
        let notchWidth = right.minX - left.maxX
        let notchHeight = safeAreaInsets.top
        return NSRect(x: left.maxX,
                      y: frame.maxY - notchHeight,
                      width: notchWidth,
                      height: notchHeight)
    }

    /// The notch rect on a real notch, or a synthetic top-center band sized to the
    /// menu bar so the UI still has a sensible anchor on non-notch displays.
    var effectiveNotchRect: NSRect {
        if let real = notchRect { return real }
        // Fallback: a synthetic "notch" centered in the menu-bar band.
        let menuBarHeight = max(frame.maxY - visibleFrame.maxY, NSStatusBar.system.thickness)
        let width: CGFloat = 180
        return NSRect(x: frame.midX - width / 2,
                      y: frame.maxY - menuBarHeight,
                      width: width,
                      height: menuBarHeight)
    }

    /// The screen NotchShelf should attach to: prefer a notched built-in display,
    /// otherwise the main screen.
    static var notchScreen: NSScreen? {
        screens.first(where: { $0.hasNotch }) ?? main ?? screens.first
    }
}
