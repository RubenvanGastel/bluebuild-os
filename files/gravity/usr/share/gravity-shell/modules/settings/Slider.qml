import QtQuick
import qs.services

// A setting with a level (0..1): its name, a line about it and a track to drag or click.
// `moved` while dragging, so things can follow live; `committed` once let go, to save.
// With a `defaultValue`, a tick under the track marks it, the handle snaps to it when
// close, and a Reset button (shown once moved off it) or a double-click goes back to it.
Rectangle {
    id: root

    property string label
    property string description
    property real value: 0
    property real defaultValue: -1
    readonly property bool hasDefault: defaultValue >= 0 && defaultValue <= 1
    readonly property bool atDefault: hasDefault && Math.abs(shown - defaultValue) < 0.005

    // The level as words, top right; follows the handle while dragging.
    property string valueText: Math.round(shown * 100) + "%"

    signal moved(real v)
    signal committed(real v)

    // The level as drawn: the pointer's while dragging, the setting's otherwise.
    readonly property real shown: mouse.pressed ? mouse.level : Math.max(0, Math.min(1, value))

    width: parent?.width ?? 0
    implicitHeight: texts.implicitHeight + track.height + 44
    radius: 20
    color: Theme.deep
    opacity: enabled ? 1 : 0.5

    Column {
        id: texts

        x: 18
        y: 12
        width: parent.width - 36
        spacing: 2

        Text {
            width: parent.width - status.width - amount.implicitWidth - 16
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

    Text {
        id: amount

        anchors.right: status.visible ? status.left : parent.right
        anchors.rightMargin: status.visible ? 6 : 18
        anchors.verticalCenter: status.verticalCenter
        text: root.valueText
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: 12
        font.weight: Font.Bold
        font.features: { "tnum": 1 }
    }

    // "Default" while at it; otherwise a Reset button back to it.
    Rectangle {
        id: status

        visible: root.hasDefault
        anchors.right: parent.right
        anchors.rightMargin: 14
        y: 8
        width: statusText.implicitWidth + 20
        height: 26
        radius: 13
        color: root.atDefault ? "transparent" : resetMouse.containsMouse ? Theme.hover(Theme.tonal, 1.15) : Theme.tonal

        Text {
            id: statusText

            anchors.centerIn: parent
            text: root.atDefault ? I18n.tr("Default") : I18n.tr("Reset")
            color: root.atDefault ? Theme.textDim : Theme.tonalInk
            font.family: Theme.font
            font.pixelSize: 12
            font.weight: Font.Bold
        }

        MouseArea {
            id: resetMouse

            anchors.fill: parent
            enabled: !root.atDefault
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.committed(root.defaultValue)
        }
    }

    Item {
        id: track

        x: 18
        anchors.top: texts.bottom
        anchors.topMargin: 8
        width: parent.width - 36
        height: 28

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 12
            radius: 6
            color: Theme.tonal
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: handle.x + handle.width / 2
            height: 12
            radius: 6
            color: Theme.gold
        }

        // The default: a tick just under the track, always shown.
        Rectangle {
            visible: root.hasDefault
            anchors.top: parent.bottom
            anchors.topMargin: 2
            x: root.defaultValue * (track.width - handle.width) + handle.width / 2 - width / 2
            width: 3
            height: 8
            radius: 1.5
            color: root.atDefault ? Theme.gold : Theme.textDim
        }

        Rectangle {
            id: handle

            anchors.verticalCenter: parent.verticalCenter
            x: root.shown * (track.width - width)
            width: mouse.pressed ? 7 : 5
            height: mouse.pressed ? 28 : 24
            radius: width / 2
            color: Theme.gold
        }

        MouseArea {
            id: mouse

            property real level: 0

            function levelAt(px: real): real {
                const v = Math.max(0, Math.min(1, px / track.width));
                return root.hasDefault && Math.abs(v - root.defaultValue) < 0.03 ? root.defaultValue : v;
            }

            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            preventStealing: true
            onPressed: e => {
                level = levelAt(e.x - 6);
                root.moved(level);
            }
            onPositionChanged: e => {
                if (!pressed)
                    return;
                level = levelAt(e.x - 6);
                root.moved(level);
            }
            onReleased: root.committed(level)
            onDoubleClicked: if (root.hasDefault) {
                level = root.defaultValue;
                root.committed(level);
            }
        }
    }
}
