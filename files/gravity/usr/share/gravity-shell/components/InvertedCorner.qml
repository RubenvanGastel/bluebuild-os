import QtQuick
import QtQuick.Shapes

// Bar-coloured fill between two edges and a quarter circle, so a surface flows into the
// edge next to it in a concave curve (the bar into the screen edges, the quick panel into
// the bar). Fills the top-left corner of its square; mirrored, the top-right one; flipped,
// the bottom one.
Shape {
    id: cornerShape

    property real size
    property color fill
    property bool mirrored: false
    property bool flipped: false

    width: size
    height: size
    preferredRendererType: Shape.CurveRenderer

    transform: Scale {
        origin.x: cornerShape.width / 2
        origin.y: cornerShape.height / 2
        xScale: cornerShape.mirrored ? -1 : 1
        yScale: cornerShape.flipped ? -1 : 1
    }

    ShapePath {
        strokeColor: "transparent"
        fillColor: cornerShape.fill
        startX: 0
        startY: 0
        PathLine {
            x: cornerShape.width
            y: 0
        }
        PathArc {
            x: 0
            y: cornerShape.height
            radiusX: cornerShape.width
            radiusY: cornerShape.height
            direction: PathArc.Counterclockwise
        }
        PathLine {
            x: 0
            y: 0
        }
    }
}
