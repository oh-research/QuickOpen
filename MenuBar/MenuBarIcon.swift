import Cocoa

/// Creates the QuickOpen menu bar icon as a template `NSImage`.
///
/// The design reduces the app icon (translucent folder + pointing-finger
/// tap with ripples) to three visual layers, ordered back to front:
///
/// 1. **Outer rounded rectangle** (alpha 1.0) — window/screen frame.
/// 2. **Ripple ring** (alpha 0.35) — background guide conveying the
///    "tap" gesture.
/// 3. **Folder silhouette + tap dot** (alpha 1.0) — signature motif:
///    "folder + click".
///
/// The image is marked `isTemplate = true`, so AppKit automatically
/// tints it for light/dark menu bars and highlight states — never color
/// it manually.
///
/// All metrics are tuned on an 18pt reference canvas
/// (`scale = rect.width / 18`). They scale linearly to any size.
enum MenuBarIcon {

    /// Returns a new template image. `size` defaults to `18`, matching
    /// the standard `NSStatusItem.squareLength` on macOS.
    static func make(size: CGFloat = 18) -> NSImage {
        let nsSize = NSSize(width: size, height: size)
        let image = NSImage(size: nsSize, flipped: true) { rect in
            draw(in: rect)
            return true
        }
        image.isTemplate = true
        return image
    }

    // MARK: - Drawing

    private static func draw(in rect: CGRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let scale = rect.width / 18.0

        // Layer 1 — Outer frame (alpha 1.0).
        let borderWidth = 1.0 * scale
        let borderInset = 1.0 * scale
        let borderCornerRadius = 3.0 * scale
        let borderRect = rect.insetBy(dx: borderInset, dy: borderInset)

        ctx.setStrokeColor(NSColor.black.cgColor)
        ctx.setLineWidth(borderWidth)
        ctx.setLineJoin(.round)
        ctx.addPath(CGPath(
            roundedRect: borderRect,
            cornerWidth: borderCornerRadius,
            cornerHeight: borderCornerRadius,
            transform: nil
        ))
        ctx.strokePath()

        // Layer 2 — Tap ripple (alpha 0.35). A single stroked ring reads
        // more cleanly at 18pt than multiple concentric rings.
        let tapCenter = CGPoint(x: 13.0 * scale, y: 13.0 * scale)
        let rippleRadius = 2.8 * scale
        let rippleLineWidth = 0.7 * scale

        ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.35).cgColor)
        ctx.setLineWidth(rippleLineWidth)
        ctx.addEllipse(in: CGRect(
            x: tapCenter.x - rippleRadius,
            y: tapCenter.y - rippleRadius,
            width: rippleRadius * 2,
            height: rippleRadius * 2
        ))
        ctx.strokePath()

        // Layer 3 — Folder silhouette + tap dot (alpha 1.0).
        ctx.setFillColor(NSColor.black.cgColor)

        // Tab — small raised bump on top-left of the body. Overlaps the
        // body's top edge so the combined silhouette reads as one shape.
        let tabRect = CGRect(
            x: 3.0 * scale,
            y: 4.2 * scale,
            width: 4.0 * scale,
            height: 1.6 * scale
        )
        ctx.addPath(CGPath(
            roundedRect: tabRect,
            cornerWidth: 0.4 * scale,
            cornerHeight: 0.4 * scale,
            transform: nil
        ))
        ctx.fillPath()

        // Body — main folder rectangle.
        let bodyRect = CGRect(
            x: 3.0 * scale,
            y: 5.5 * scale,
            width: 8.0 * scale,
            height: 5.5 * scale
        )
        ctx.addPath(CGPath(
            roundedRect: bodyRect,
            cornerWidth: 1.0 * scale,
            cornerHeight: 1.0 * scale,
            transform: nil
        ))
        ctx.fillPath()

        // Tap dot — centered inside the ripple.
        let dotRadius = 1.2 * scale
        ctx.addEllipse(in: CGRect(
            x: tapCenter.x - dotRadius,
            y: tapCenter.y - dotRadius,
            width: dotRadius * 2,
            height: dotRadius * 2
        ))
        ctx.fillPath()
    }
}
