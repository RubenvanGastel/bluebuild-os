import QtQuick
import qs.services

// A network or device on a settings page: its icon, name and state, buttons at the end,
// and room underneath for more (a password, details, its settings) while `expanded`.
// The connected one is filled with the accent.
Rectangle {
    id: root

    property string icon
    property string title
    property string subtitle
    property bool selected: false
    property bool expanded: false
    // Buttons at the end of the row: [{ id, icon }]; clicking one gives `acted(id)`.
    property var actions: []
    default property alias extra: more.data

    signal clicked
    signal acted(string id)

    readonly property color ink: selected ? Theme.goldInk : Theme.text

    width: parent?.width ?? 0
    height: 60 + (expanded ? more.implicitHeight + 14 : 0)
    radius: selected ? 20 : 30
    color: selected ? Theme.gold : mouse.containsMouse ? Theme.hover(Theme.deep, 1.15) : Theme.deep
    clip: true

    Behavior on height {
        NumberAnimation {
            duration: Theme.normal
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.emphasized
        }
    }
    Behavior on color {
        ColorAnimation {
            duration: Theme.fast
        }
    }

    MouseArea {
        id: mouse

        width: parent.width
        height: 60
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Rectangle {
        id: badge

        x: 10
        y: 10
        width: 40
        height: 40
        radius: 20
        color: root.selected ? Qt.alpha(Theme.goldInk, 0.12) : Theme.dusk

        Text {
            anchors.centerIn: parent
            text: root.icon
            color: root.selected ? Theme.goldInk : Theme.tonalInk
            font.family: "Symbols Nerd Font"
            font.pixelSize: 20
        }
    }

    Column {
        anchors.left: badge.right
        anchors.leftMargin: 12
        anchors.right: buttons.left
        anchors.rightMargin: 10
        y: 30 - height / 2
        spacing: 1

        Text {
            width: parent.width
            text: root.title
            elide: Text.ElideRight
            color: root.ink
            font.family: Theme.font
            font.pixelSize: 14
            font.weight: Font.Bold
        }

        Text {
            visible: text !== ""
            width: parent.width
            text: root.subtitle
            elide: Text.ElideRight
            color: root.selected ? Qt.alpha(Theme.goldInk, 0.75) : Theme.textDim
            font.family: Theme.font
            font.pixelSize: 12
            font.weight: Font.Medium
        }
    }

    Row {
        id: buttons

        anchors.right: parent.right
        anchors.rightMargin: 12
        y: 12
        spacing: 6

        Repeater {
            model: root.actions

            PillButton {
                required property var modelData

                icon: modelData.icon
                tinted: root.selected
                onClicked: root.acted(modelData.id)
            }
        }
    }

    Item {
        id: more

        x: 14
        y: 60
        width: parent.width - 28
        implicitHeight: childrenRect.height
        visible: root.expanded
    }
}
