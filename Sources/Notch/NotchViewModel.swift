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

    /// Expanded panel dimensions.
    let expandedWidth: CGFloat = 420
    let expandedHeight: CGFloat = 190

    /// The animation used for every open/close transition.
    let animation: Animation = .spring(response: 0.4, dampingFraction: 0.8)

    var isOpen: Bool { state == .expanded || isDropTargeted }

    /// The size the visible panel should currently occupy.
    var currentSize: CGSize {
        if isOpen {
            return CGSize(width: expandedWidth, height: expandedHeight)
        }
        // Collapsed: hug the physical notch, padded slightly so the silhouette is
        // visible just outside the camera housing.
        return CGSize(width: notchSize.width + 8, height: notchSize.height)
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
