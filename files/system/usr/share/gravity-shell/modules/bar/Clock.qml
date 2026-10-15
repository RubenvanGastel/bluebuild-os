import QtQuick
import Quickshell
import qs.services
import qs.components

// Time with the date beside it.
Row {
    id: root

    property color color: Theme.cream

    spacing: 8

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    FloatText {
        anchors.verticalCenter: parent.verticalCenter
        width: implicitWidth
        height: 24
        color: root.color
        font.pixelSize: 14
        font.weight: Font.Bold
        text: Qt.formatDateTime(clock.date, Config.use24h ? "HH:mm" : "h:mm AP")
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 4
        height: 4
        radius: 2
        color: root.color
        opacity: 0.5
    }

    FloatText {
        anchors.verticalCenter: parent.verticalCenter
        width: implicitWidth
        height: 24
        color: root.color
        opacity: 0.8
        font.pixelSize: 14
        font.weight: Font.Medium
        text: Qt.formatDateTime(clock.date, "ddd d MMM")
    }
}
