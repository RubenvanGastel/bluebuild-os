import QtQuick
import qs.services

// A heading on a settings page and the settings under it.
Column {
    id: root

    property string title
    default property alias content: body.data

    width: parent?.width ?? 0
    spacing: 10

    Text {
        visible: root.title !== ""
        text: root.title
        color: Theme.textDim
        font.family: Theme.font
        font.pixelSize: 13
        font.weight: Font.Bold
    }

    Column {
        id: body

        width: parent.width
        spacing: 6
    }
}
