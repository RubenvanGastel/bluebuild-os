import QtQuick
import QtQuick.Shapes

// A soft radial glow. Cheaper than a blur effect and looks the same for round light.
Shape {
    id: root

    property color color: "white"
    property real strength: 0.5

    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        strokeColor: "transparent"
        fillGradient: RadialGradient {
            centerX: root.width / 2
            centerY: root.height / 2
            centerRadius: Math.min(root.width, root.height) / 2
            focalX: centerX
            focalY: centerY

            GradientStop {
                position: 0
                color: Qt.rgba(root.color.r, root.color.g, root.color.b, root.strength)
            }
            GradientStop {
                position: 0.45
                color: Qt.rgba(root.color.r, root.color.g, root.color.b, root.strength * 0.35)
            }
            GradientStop {
                position: 1
                color: Qt.rgba(root.color.r, root.color.g, root.color.b, 0)
            }
        }

        PathAngleArc {
            centerX: root.width / 2
            centerY: root.height / 2
            radiusX: root.width / 2
            radiusY: root.height / 2
            startAngle: 0
            sweepAngle: 360
        }
    }
}
