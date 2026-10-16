import QtQuick
import qs.services

// CPU and memory use as two short bars, each behind its icon.
// A bar turns rose when the value runs high. Lives in a pill in the bar that opens the
// monitor panel.
Row {
    id: root

    spacing: 12

    Meter {
        icon: "\u{f061a}"
        value: SysMon.cpu
        high: SysMon.cpu > 0.9
    }

    Meter {
        icon: "\u{f035b}"
        value: SysMon.mem
        high: SysMon.mem > 0.9
    }

    component Meter: Row {
        id: meter

        property string icon
        property real value
        property bool high: false

        anchors.verticalCenter: parent?.verticalCenter
        spacing: 5

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: meter.icon
            color: meter.high ? Theme.rose : Theme.text
            font.family: "Symbols Nerd Font"
            font.pixelSize: 14
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 30
            height: 6
            radius: 3
            color: Qt.alpha(Theme.text, 0.18)

            Rectangle {
                width: Math.max(parent.height, parent.width * Math.max(0, Math.min(1, meter.value)))
                height: parent.height
                radius: parent.radius
                color: meter.high ? Theme.rose : Theme.glow

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.normal
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: Theme.normal
                    }
                }
            }
        }
    }
}
