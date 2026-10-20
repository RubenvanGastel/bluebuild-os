import QtQuick
import qs.services

// A pill-shaped button with an icon and/or a label: tonal, filled with the accent, or
// rose for something that can't be undone. On an accent surface (`tinted`) it's a faint
// tint of the text colour instead.
Rectangle {
    id: root

    property string icon
    property string label
    property bool accent: false
    property bool danger: false
    property bool tinted: false

    signal clicked

    readonly property color ink: accent ? Theme.goldInk : tinted ? Theme.goldInk : danger ? Theme.rose : Theme.tonalInk

    implicitWidth: label === "" ? 36 : row.implicitWidth + 32
    implicitHeight: 36
    radius: height / 2
    color: {
        if (tinted)
            return Qt.alpha(Theme.goldInk, mouse.containsMouse ? 0.22 : 0.12);
        const base = accent ? Theme.gold : Theme.tonal;
        return mouse.containsMouse ? Theme.hover(base, 1.2) : base;
    }
    opacity: enabled ? 1 : 0.5
    scale: mouse.pressed ? 0.94 : 1

    Behavior on color {
        ColorAnimation {
            duration: Theme.fast
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: Theme.fast
            easing.type: Easing.OutBack
        }
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 6

        Text {
            visible: root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            color: root.ink
            font.family: "Symbols Nerd Font"
            font.pixelSize: 16
        }

        Text {
            visible: root.label !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: root.ink
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: Font.Bold
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
