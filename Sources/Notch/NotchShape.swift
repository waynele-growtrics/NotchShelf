import SwiftUI

/// The signature notch silhouette: flat across the top (it fuses with the screen
/// bezel), with the two bottom corners rounded so content appears to flow out of
/// the notch. The top corners get a small inverse curve so the shape blends into
/// the hardware notch rather than meeting it at a hard angle.
struct NotchShape: Shape {
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat

    init(topCornerRadius: CGFloat = 6, bottomCornerRadius: CGFloat = 14) {
        self.topCornerRadius = topCornerRadius
        self.bottomCornerRadius = bottomCornerRadius
    }

    /// Animate the corner radii together as the panel expands/collapses.
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topCornerRadius, bottomCornerRadius) }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let top = topCornerRadius
        let bottom = min(bottomCornerRadius, rect.height / 2)

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))

        // Inverse top-left curve flowing down from the bezel.
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + top, y: rect.minY + top),
            control: CGPoint(x: rect.minX + top, y: rect.minY))

        // Left edge down to the bottom-left rounded corner.
        path.addLine(to: CGPoint(x: rect.minX + top, y: rect.maxY - bottom))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + top + bottom, y: rect.maxY),
            control: CGPoint(x: rect.minX + top, y: rect.maxY))

        // Bottom edge to the bottom-right rounded corner.
        path.addLine(to: CGPoint(x: rect.maxX - top - bottom, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - top, y: rect.maxY - bottom),
            control: CGPoint(x: rect.maxX - top, y: rect.maxY))

        // Right edge up to the inverse top-right curve.
        path.addLine(to: CGPoint(x: rect.maxX - top, y: rect.minY + top))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - top, y: rect.minY))

        path.closeSubpath()
        return path
    }
}
