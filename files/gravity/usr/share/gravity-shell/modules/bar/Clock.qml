import QtQuick
import Quickshell
import qs.services
import qs.components

// Time with the date beside it (Config.showDate). Vertical, along a side: the hours above
// the minutes, the day above the month.
Grid {
    id: root

    property color color: Theme.text
    property bool vertical: false

    columns: vertical ? 1 : 3
    spacing: vertical ? 2 : 8
    horizontalItemAlignment: Grid.AlignHCenter
    verticalItemAlignment: Grid.AlignVCenter

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    FloatText {
        width: implicitWidth
        height: root.vertical ? implicitHeight : 24
        horizontalAlignment: Text.AlignHCenter
        color: root.color
        font.pixelSize: 14
        font.weight: Font.Bold
        lineHeight: 0.9
        text: root.vertical ? Qt.formatDateTime(clock.date, Config.use24h ? "HH\nmm" : "h\nmm") : Qt.formatDateTime(clock.date, Config.use24h ? "HH:mm" : "h:mm AP")
    }

    Rectangle {
        visible: Config.showDate
        width: root.vertical ? 12 : 4
        height: root.vertical ? 2 : 4
        radius: 2
        color: root.color
        opacity: 0.5
    }

    FloatText {
        visible: Config.showDate
        width: implicitWidth
        height: root.vertical ? implicitHeight : 24
        horizontalAlignment: Text.AlignHCenter
        color: root.color
        opacity: 0.8
        font.pixelSize: root.vertical ? 12 : 14
        font.weight: Font.Medium
        lineHeight: 0.9
        text: Qt.formatDateTime(clock.date, root.vertical ? "d\nMMM" : "ddd d MMM")
    }
}
