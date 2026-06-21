import SwiftUI
import Combine

/// Shared UI state for the notch panel: its measured geometry, open/closed state,
/// and the size targets the SwiftUI layer animates between.
@MainActor
final class NotchViewModel: ObservableObject {

    enum State {
        case collapsed
        case expanded
    }

    @Published var state: State = .collapsed
    /// True while a file drag is hovering the notch — forces it open so the user
    /// can drop even if they didn't hover first.
    @Published var isDropTargeted: Bool = false

    /// Measured physical (or synthetic) notch size, in points.
    @Published var notchSize: CGSize = CGSize(width: 180, height: 32)

    /// Expanded panel dimensions. Width follows the user's setting. Height has to
    /// fit: notch inset + now-playing row + progress bar + Files/Clipboard tabs +
    /// divider + a row of 70pt cells + the status footer.
    var expandedWidth: CGFloat { CGFloat(Settings.shared.panelWidth) }
    var expandedHeight: CGFloat { notchSize.height + 218 }

    /// The animation used for every open/close transition.
    let animation: Animation = .spring(response: 0.4, dampingFraction: 0.8)

    var isOpen: Bool { state == .expanded || isDropTargeted }

    /// The size the visible panel should currently occupy.
    var currentSize: CGSize {
        if isOpen {
            return CGSize(width: expandedWidth, height: expandedHeight)
        }
        // Collapsed: hug the physical notch exactly so the window never covers
        // (and blocks clicks on) the menu bar or content beside/below the notch.
        return CGSize(width: notchSize.width, height: notchSize.height)
    }

    func open() {
        guard state != .expanded else { return }
        withAnimation(animation) { state = .expanded }
    }

    func close() {
        guard state != .collapsed else { return }
        withAnimation(animation) { state = .collapsed }
    }
}
