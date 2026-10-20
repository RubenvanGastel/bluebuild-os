import QtQuick
import qs.services

// One of a few options as an M3 Expressive button group under its name: the chosen one is
// filled with the accent and squares off a little. They share the width, or with `wrap`
// each takes what it needs and they flow onto more lines (for longer lists).
Column {
    id: root

    property string label
    property string description
    // [{ value, label, icon (optional) }]
    property var options: []
    property var value
    property bool wrap: false

    signal chosen(var value)

    width: parent?.width ?? 0
    spacing: 8
    opacity: enabled ? 1 : 0.5

    Column {
        visible: root.label !== "" || root.description !== ""
        width: parent.width
        spacing: 2

        Text {
            visible: root.label !== ""
            text: root.label
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 14
            font.weight: Font.Bold
        }

        Text {
            visible: root.description !== ""
            width: parent.width
            text: root.description
            wrapMode: Text.Wrap
            color: Theme.textDim
            font.family: Theme.font
            font.pixelSize: 12
            font.weight: Font.Medium
        }
    }

    Flow {
        id: group

        width: parent.width
        spacing: 6

        Repeater {
            model: root.options

            Rectangle {
                id: option

                required property var modelData
                readonly property bool selected: root.value === modelData.value

                width: root.wrap ? content.implicitWidth + 32 : (group.width - group.spacing * (root.options.length - 1)) / root.options.length
                height: root.wrap ? 36 : 44
                radius: selected ? 12 : height / 2
                color: selected ? Theme.gold : mouse.containsMouse ? Theme.hover(Theme.tonal, 1.25) : Theme.tonal

                Behavior on radius {
                    NumberAnimation {
                        duration: Theme.normal
                        easing.type: Easing.OutBack
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: Theme.fast
                    }
                }

                Row {
                    id: content

                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        visible: option.modelData.icon !== undefined
                        anchors.verticalCenter: parent.verticalCenter
                        text: option.modelData.icon ?? ""
                        color: option.selected ? Theme.goldInk : Theme.tonalInk
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 16
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: option.modelData.label
                        color: option.selected ? Theme.goldInk : Theme.tonalInk
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
                    onClicked: root.chosen(option.modelData.value)
                }
            }
        }
    }
}
