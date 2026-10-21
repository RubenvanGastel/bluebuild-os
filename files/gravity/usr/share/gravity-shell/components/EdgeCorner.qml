import QtQuick
import qs.services

// An InvertedCorner placed in the bar's own terms, whichever screen edge it is on: `u` runs
// along the bar from its start (the left or top end), `v` away from the screen edge into the
// screen. `near` fills the side of the square toward the edge, `high` the side toward the
// bar's far end. Its parent must cover the whole screen (or a copy of it, as the picker's).
InvertedCorner {
    property real u
    property real v
    property bool near: true
    property bool high: false

    readonly property string edge: Theme.barEdge

    x: edge === "left" ? v : edge === "right" ? parent.width - v - size : u
    y: edge === "top" ? v : edge === "bottom" ? parent.height - v - size : u
    mirrored: edge === "left" ? !near : edge === "right" ? near : high
    flipped: edge === "top" ? !near : edge === "bottom" ? near : high
}
