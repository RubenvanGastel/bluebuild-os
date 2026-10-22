import QtQuick
import QtQuick.Shapes
import qs.services

// One of Material 3 Expressive's shapes (services/Shapes.qml), filling the item.
Shape {
    id: root

    property string shape: "circle"
    property color color: Theme.gold

    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: root.color
        strokeWidth: -1
        scale: Qt.size(root.width, root.height)

        PathSvg {
            path: Shapes.paths[root.shape] ?? Shapes.paths.circle
        }
    }
}
