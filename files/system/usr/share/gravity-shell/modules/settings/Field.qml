import QtQuick
import qs.services

// A line of text in a pill, with its name above (optional). Enter or leaving the field
// gives `accepted`; while it isn't being edited it shows `text`.
Column {
    id: root

    property string label
    property string description
    property string text
    property string placeholder
    property bool password: false
    // Shown in rose under the field.
    property string error
    readonly property alias input: input

    signal accepted(string text)

    width: parent?.width ?? 0
    spacing: 8

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

    Rectangle {
        width: parent.width
        height: 44
        radius: 22
        color: Theme.deep
        border.width: input.activeFocus || root.error !== "" ? 2 : 0
        border.color: root.error !== "" ? Theme.rose : Theme.gold

        TextInput {
            id: input

            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            echoMode: root.password ? TextInput.Password : TextInput.Normal
            passwordCharacter: "•"
            color: Theme.text
            selectionColor: Theme.gold
            selectedTextColor: Theme.goldInk
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: Font.Medium
            clip: true
            onAccepted: root.accepted(text)
            onActiveFocusChanged: if (!activeFocus && text !== root.text)
                root.accepted(text)
            Keys.onEscapePressed: event => {
                text = root.text;
                focus = false;
                event.accepted = true;
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text === ""
                text: root.placeholder
                color: Theme.textDim
                font: input.font
            }
        }

        // Follows the setting, except while it is being typed in.
        Binding {
            target: input
            property: "text"
            value: root.text
            when: !input.activeFocus
            restoreMode: Binding.RestoreNone
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            onPressed: mouse => {
                input.forceActiveFocus();
                mouse.accepted = false;
            }
        }
    }

    Text {
        visible: root.error !== ""
        width: parent.width
        text: root.error
        wrapMode: Text.Wrap
        color: Theme.rose
        font.family: Theme.font
        font.pixelSize: 12
        font.weight: Font.Bold
    }
}
