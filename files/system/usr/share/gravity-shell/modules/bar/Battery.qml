import QtQuick
import Quickshell.Services.UPower
import qs.services

// Battery outline with a fill that eases to the current level. Hidden on desktops.
Item {
    id: root

    readonly property var dev: UPower.displayDevice
    readonly property real level: dev?.percentage ?? 0
    readonly property bool charging: dev?.state === UPowerDeviceState.Charging || dev?.state === UPowerDeviceState.PendingCharge || dev?.state === UPowerDeviceState.FullyCharged
    readonly property bool low: level < 0.15 && !charging

    implicitWidth: row.implicitWidth
    implicitHeight: 24
    onChargingChanged: if (!charging)
        fill.opacity = 1

    visible: (dev?.isLaptopBattery ?? false) && (dev?.isPresent ?? false)

    Row {
        id: row

        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Item {
            width: 24
            height: 12
            anchors.verticalCenter: parent.verticalCenter

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
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(root.level * 100) + "%"
            color: root.low ? Theme.rose : Theme.text
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: Font.Bold
        }
    }
}
