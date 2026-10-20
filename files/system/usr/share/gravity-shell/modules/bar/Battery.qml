import QtQuick
import QtQuick.Shapes
import Quickshell.Services.UPower
import qs.services

// Battery outline with a fill that eases to the current level, and a bolt beside it
// while on AC: gold while charging, dim when plugged in but not charging (full or
// held by a charge limit). Hidden on desktops. Along a side the level goes under it.
Item {
    id: root

    property bool vertical: false

    readonly property var dev: UPower.displayDevice
    readonly property real level: dev?.percentage ?? 0
    readonly property bool charging: dev?.state === UPowerDeviceState.Charging
    readonly property bool plugged: charging || !UPower.onBattery
    readonly property bool low: level < 0.15 && !plugged

    implicitWidth: row.implicitWidth
    implicitHeight: vertical ? row.implicitHeight : 24
    onChargingChanged: if (!charging)
        fill.opacity = 1

    visible: (dev?.isLaptopBattery ?? false) && (dev?.isPresent ?? false)

    Grid {
        id: row

        anchors.verticalCenter: parent.verticalCenter
        columns: root.vertical ? 1 : 3
        spacing: root.vertical ? 3 : 6
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter

        // Lightning bolt; slides open when the charger is connected.
        Item {
            width: root.plugged || root.vertical ? 8 : 0
            height: root.plugged || !root.vertical ? 13 : 0
            opacity: root.plugged ? 1 : 0
            clip: true

            Behavior on width {
                NumberAnimation {
                    duration: Theme.slow
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on height {
                NumberAnimation {
                    duration: Theme.slow
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.slow
                    easing.type: Easing.OutCubic
                }
            }

            Shape {
                width: 8
                height: 13
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeColor: "transparent"
                    fillColor: root.charging ? Theme.gold : Theme.textDim
                    PathPolyline {
                        path: [Qt.point(5, 0), Qt.point(0, 7.5), Qt.point(3.5, 7.5), Qt.point(2.5, 13), Qt.point(8, 5.5), Qt.point(4.5, 5.5), Qt.point(5, 0)]
                    }
                }
            }
        }

        Item {
            width: 24
            height: 12

            Rectangle {
                id: body

                width: 21
                height: 12
                radius: 3
                color: "transparent"
                border.color: root.low ? Theme.rose : Theme.text
                border.width: 1.4

                Rectangle {
                    id: fill

                    x: 2.2
                    y: 2.2
                    height: parent.height - 4.4
                    width: Math.max(1.5, (parent.width - 4.4) * root.level)
                    radius: 1.5
                    color: root.low ? Theme.rose : root.charging ? Theme.gold : Theme.glow

                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.slow
                            easing.type: Easing.OutCubic
                        }
                    }

                    // Gentle shimmer while charging.
                    SequentialAnimation on opacity {
                        running: root.charging
                        loops: Animation.Infinite
                        NumberAnimation {
                            to: 0.55
                            duration: 900
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            to: 1
                            duration: 900
                            easing.type: Easing.InOutSine
                        }
                    }
                }
            }

            Rectangle {
                x: body.width + 0.5
                anchors.verticalCenter: body.verticalCenter
                width: 2
                height: 5
                radius: 1
                color: body.border.color
            }
        }

        Text {
            text: Math.round(root.level * 100) + (root.vertical ? "" : "%")
            color: root.low ? Theme.rose : Theme.text
            font.family: Theme.font
            font.pixelSize: root.vertical ? 11 : 13
            font.weight: Font.Bold
        }
    }
}
