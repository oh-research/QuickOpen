import Cocoa

/// Creates the QuickOpen menu bar icon as a template `NSImage`.
///
/// The design is two same-size landscape rounded rectangles layered
/// front-and-back: a back rectangle in the upper-left and a front
/// rectangle offset diagonally down-and-right. The front rectangle is
/// opaque — its interior is cleared from the back outline so the back
/// appears to be hidden behind it. The image is marked
/// `isTemplate = true`, so AppKit automatically tints it for dark/light
/// menu bars and highlight states — never color it manually.
///
/// All metrics are tuned in the constants below (`draw(in:)`) using a
/// 18pt reference canvas. They scale linearly to any size.
enum MenuBarIcon {

    /// Returns a new template image. `size` defaults to `18`, which matches
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

    /// Tunable proportions in 18pt units. Adjust here, then re-render.
    private static func draw(in rect: CGRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let scale = rect.width / 18.0
        let lineWidth = 1.0 * scale

        // Two same-size landscape (wider than tall) rounded rectangles,
        // layered with the front offset diagonally from the back.
        let rectWidth = 12.0 * scale
        let rectHeight = 6.0 * scale
        let offsetX = 4.0 * scale
        let offsetY = 4.0 * scale
        let cornerRadius = 1.0 * scale

        // Back rectangle (upper-left).
        let backX = 1.0 * scale
        let backY = 4.0 * scale

        // Front rectangle (lower-right, offset from back).
        let frontX = backX + offsetX
        let frontY = backY + offsetY

        let backPath = CGPath(
            roundedRect: CGRect(x: backX, y: backY, width: rectWidth, height: rectHeight),
            cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil
        )
        let frontPath = CGPath(
            roundedRect: CGRect(x: frontX, y: frontY, width: rectWidth, height: rectHeight),
            cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil
        )

        // Slightly inflated path used to erase the back outline cleanly along
        // the front boundary (covers the half-stroke that would otherwise
        // remain when fillPath() is called with the exact front path).
        let inflate = lineWidth
        let clearPath = CGPath(
            roundedRect: CGRect(
                x: frontX - inflate,
                y: frontY - inflate,
                width: rectWidth + inflate * 2,
                height: rectHeight + inflate * 2
            ),
            cornerWidth: cornerRadius + inflate,
            cornerHeight: cornerRadius + inflate,
            transform: nil
        )

        ctx.setLineWidth(lineWidth)
        ctx.setStrokeColor(NSColor.black.cgColor)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        // 1. Stroke the back rectangle outline (full).
        ctx.addPath(backPath)
        ctx.strokePath()

        // 2. Erase the area where the front rectangle will sit so the back
        //    outline does not bleed through.
        ctx.saveGState()
        ctx.setBlendMode(.clear)
        ctx.addPath(clearPath)
        ctx.fillPath()
        ctx.restoreGState()

        // 3. Stroke the front rectangle outline on top of the cleared area.
        ctx.addPath(frontPath)
        ctx.strokePath()
    }
}
