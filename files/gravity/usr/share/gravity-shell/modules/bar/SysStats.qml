import QtQuick
import qs.services

// CPU and memory use as two short bars, each behind its icon (under it, standing up,
// along a side). A bar turns rose when the value runs high. Lives in a pill in the bar
// that opens the monitor panel.
Grid {
    id: root

    property bool vertical: false

    columns: vertical ? 1 : 2
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

    component Meter: Grid {
        id: meter

        property string icon
        property real value
        property bool high: false

        columns: root.vertical ? 1 : 2
        spacing: 5
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter

        Text {
            text: meter.icon
            color: meter.high ? Theme.rose : Theme.text
            font.family: "Symbols Nerd Font"
            font.pixelSize: 14
        }

        Rectangle {
            id: track

            width: root.vertical ? 6 : 30
            height: root.vertical ? 24 : 6
            radius: 3
            color: Qt.alpha(Theme.text, 0.18)

            // Fills from the left, or up from the bottom.
            Rectangle {
                readonly property real fill: Math.max(0, Math.min(1, meter.value))

                y: root.vertical ? track.height - height : 0
                width: root.vertical ? track.width : Math.max(track.height, track.width * fill)
                height: root.vertical ? Math.max(track.width, track.height * fill) : track.height
                radius: parent.radius
                color: meter.high ? Theme.rose : Theme.glow

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.normal
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on height {
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
