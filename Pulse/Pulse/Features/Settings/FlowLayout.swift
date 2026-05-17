import SwiftUI

/// Lightweight flow layout used by the category chip row in EventTypesSection.
/// Lives outside the section file so other parts of Settings can reuse it.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        // If the parent didn't propose a width (`.unspecified`), we'd otherwise return
        // the sum of all chip widths as our intrinsic width — which can push the parent
        // wider than the viewport, leading to the "I can scroll horizontally a bit"
        // bug. Clamp to a sensible bound so an unbounded proposal can't propagate.
        let proposedWidth = proposal.width ?? 0
        let width = (proposedWidth.isFinite && proposedWidth > 0) ? proposedWidth : 0
        var totalHeight: CGFloat = 0
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if width > 0, lineWidth + size.width > width, lineWidth > 0 {
                totalHeight += lineHeight + spacing
                lineWidth = 0
                lineHeight = 0
            }
            lineWidth += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        totalHeight += lineHeight
        return CGSize(width: width, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
