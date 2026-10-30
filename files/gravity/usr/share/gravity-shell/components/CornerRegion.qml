import QtQuick
import Quickshell

// The shape an InvertedCorner (or EdgeCorner) fills, as a Region (for blur behind it):
// its square without the quarter circle it curves around. Regions are in window
// coordinates, so the corner's parent must cover the window from its top-left, as the
// bar's and the panels' do. Empty while the corner is hidden.
Region {
    id: root

    required property InvertedCorner corner

    readonly property real size: corner.visible ? corner.size : 0

    x: corner.x
    y: corner.y
    width: size
    height: size

    // The circle is centred on the corner of the square away from the fill.
    Region {
        shape: RegionShape.Ellipse
        intersection: Intersection.Subtract
        x: root.corner.x - (root.corner.mirrored ? root.size : 0)
        y: root.corner.y - (root.corner.flipped ? root.size : 0)
        width: 2 * root.size
        height: 2 * root.size
    }
}
