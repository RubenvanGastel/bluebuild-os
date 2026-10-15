import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.components

// What the bar looks like: a solid Material 3 Expressive style strip with inverted corners
// curving down into the screen at both ends, status in tonal pills, the clock in an accent
// pill and the workspaces floating on the left. Used by the bar window, and by the
// wallpaper picker, which draws an identical live copy it can slide off the screen.
Item {
    id: root

    // Output name, for the workspaces on it.
    required property string output
    // Window that tray menus open from.
    property var barWindow: null
    // The strip itself, without the corners (for input masks).
    readonly property Item strip: bar

    implicitHeight: Theme.barHeight + Theme.barCorner

    Rectangle {
        id: bar

        width: parent.width
        height: Theme.barHeight
        color: Theme.surface

        Behavior on color {
            ColorAnimation {
                duration: Theme.normal
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 6
            spacing: 12

            Workspaces {
                output: root.output
                Layout.alignment: Qt.AlignVCenter
            }

            Item {
                Layout.fillWidth: true
            }

            Tray {
                barWindow: root.barWindow
                Layout.alignment: Qt.AlignVCenter
            }

            Pill {
                color: Theme.dusk
                Layout.alignment: Qt.AlignVCenter

                RowLayout {
                    spacing: 14

                    Volume {
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Battery {
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
            }

            Pill {
                color: Theme.gold
                Layout.alignment: Qt.AlignVCenter

                Clock {
                    color: Theme.goldInk
                }
            }
        }

        // Focused window title, centred on the bar.
        FloatText {
            anchors.centerIn: parent
            width: Math.min(implicitWidth, bar.width * 0.36)
            height: parent.height
            horizontalAlignment: Text.AlignHCenter
            color: Theme.text
            font.pixelSize: 14
            font.weight: Font.DemiBold
            text: ToplevelManager.activeToplevel?.title ?? ""
        }
    }

    InvertedCorner {
        x: 0
        y: bar.height
        size: Theme.barCorner
        fill: bar.color
    }

    InvertedCorner {
        x: root.width - Theme.barCorner
        y: bar.height
        size: Theme.barCorner
        fill: bar.color
        mirrored: true
    }

    // A fully rounded tonal container around its content.
    component Pill: Rectangle {
        default property alias content: inner.data

        implicitWidth: inner.childrenRect.width + 28
        implicitHeight: 32
        radius: height / 2

        Behavior on color {
            ColorAnimation {
                duration: Theme.normal
            }
        }

        Item {
            id: inner

            anchors.centerIn: parent
            width: childrenRect.width
            height: childrenRect.height
        }
    }

    // Bar-coloured fill between the screen edge and a quarter circle, so the bar flows
    // into the screen edge in a concave curve. Drawn for the left end; mirrored for the right.
    component InvertedCorner: Shape {
        id: cornerShape

        property real size
        property color fill
        property bool mirrored: false

        width: size
        height: size
        preferredRendererType: Shape.CurveRenderer

        transform: Scale {
            origin.x: cornerShape.width / 2
            xScale: cornerShape.mirrored ? -1 : 1
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
}
