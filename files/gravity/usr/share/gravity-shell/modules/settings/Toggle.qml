import QtQuick
import qs.services

// A setting that is on or off: its name, a line about it and an M3 switch. The whole row
// flips it.
Rectangle {
    id: root

    property string label
    property string description
    property bool checked: false

    signal toggled(bool on)

    width: parent?.width ?? 0
    implicitHeight: Math.max(56, texts.implicitHeight + 24)
    radius: 20
    color: mouse.containsMouse && enabled ? Theme.hover(Theme.deep, 1.15) : Theme.deep
    opacity: enabled ? 1 : 0.5

    Behavior on color {
        ColorAnimation {
            duration: Theme.fast
        }
    }

    Column {
        id: texts

        x: 18
        anchors.verticalCenter: parent.verticalCenter
        width: track.x - x - 16
        spacing: 2

        Text {
            width: parent.width
            text: root.label
            elide: Text.ElideRight
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 14
            font.weight: Font.Bold
        }

        Text {
            visible: text !== ""
            width: parent.width
            text: root.description
            wrapMode: Text.Wrap
            color: Theme.textDim
            font.family: Theme.font
            font.pixelSize: 12
            font.weight: Font.Medium
        }
    }

    // Off: an outlined track with a small knob. On: an accent track and a larger knob.
    Rectangle {
        id: track

        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        width: 52
        height: 32
        radius: 16
        color: root.checked ? Theme.gold : Theme.dusk
        border.width: root.checked ? 0 : 2
        border.color: Theme.textDim

        Behavior on color {
            ColorAnimation {
                duration: Theme.fast
            }
        }

        Rectangle {
            property real size: mouse.pressed ? 28 : root.checked ? 24 : 16

            x: root.checked ? track.width - width - 4 : 8 - (size - 16) / 2
            anchors.verticalCenter: parent.verticalCenter
            width: size
            height: size
            radius: size / 2
            color: root.checked ? Theme.goldInk : Theme.textDim

            Behavior on x {
                NumberAnimation {
                    duration: Theme.normal
                    easing.type: Easing.OutBack
                }
            }
            Behavior on size {
                NumberAnimation {
                    duration: Theme.fast
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: Theme.fast
                }
            }
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
