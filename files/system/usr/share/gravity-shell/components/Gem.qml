import QtQuick
import QtQuick.Shapes
import qs.services

// A precious gem slowly turning in place, like the ones Kat collects.
Item {
    id: root

    property real size: 18
    property bool spinning: true

    implicitWidth: size
    implicitHeight: size

    GlowBlob {
        anchors.centerIn: parent
        width: root.size * 2.2
        height: width
        color: Theme.nebula
        strength: 0.7

        SequentialAnimation on opacity {
            running: root.spinning
            loops: Animation.Infinite
            NumberAnimation {
                from: 0.55
                to: 1
                duration: 1800
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                to: 0.55
                duration: 1800
                easing.type: Easing.InOutSine
            }
        }
    }

    Shape {
        id: gem

        anchors.centerIn: parent
        width: root.size * 0.7
        height: root.size
        preferredRendererType: Shape.CurveRenderer

        transform: Rotation {
            origin.x: gem.width / 2
            origin.y: gem.height / 2
            axis {
                x: 0
                y: 1
                z: 0
            }
            NumberAnimation on angle {
                running: root.spinning
                loops: Animation.Infinite
                from: 0
                to: 360
                duration: 7000
            }
        }

        ShapePath {
            strokeColor: Qt.rgba(1, 1, 1, 0.6)
            strokeWidth: 1
            fillGradient: LinearGradient {
                x1: 0
                y1: 0
                x2: gem.width
                y2: gem.height
                GradientStop {
                    position: 0
                    color: Theme.glow
                }
                GradientStop {
                    position: 0.55
                    color: Theme.nebula
                }
                GradientStop {
                    position: 1
                    color: Qt.darker(Theme.nebula, 1.9)
                }
            }
            PathPolyline {
                path: [Qt.point(gem.width / 2, 0), Qt.point(gem.width, gem.height * 0.36), Qt.point(gem.width / 2, gem.height), Qt.point(0, gem.height * 0.36), Qt.point(gem.width / 2, 0)]
            }
        }

        // Facet highlight.
        ShapePath {
            strokeColor: "transparent"
            fillColor: Qt.rgba(1, 1, 1, 0.35)
            PathPolyline {
                path: [Qt.point(gem.width / 2, 0), Qt.point(gem.width * 0.72, gem.height * 0.36), Qt.point(gem.width / 2, gem.height * 0.5), Qt.point(gem.width * 0.3, gem.height * 0.36), Qt.point(gem.width / 2, 0)]
            }
        }
    }
}
