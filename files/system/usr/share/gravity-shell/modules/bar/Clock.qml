import QtQuick
import Quickshell
import qs.services
import qs.components

// Time; hovering swaps it for the date with a little float.
Item {
    id: root

    property bool showDate: false
    property color color: Theme.cream

    implicitWidth: Math.max(time.implicitWidth, 60)
    implicitHeight: 24

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    FloatText {
        id: time

        anchors.fill: parent
        horizontalAlignment: Text.AlignHCenter
        color: root.color
        font.pixelSize: 14
        font.weight: Font.Bold
        text: root.showDate ? Qt.formatDateTime(clock.date, "ddd d MMM") : Qt.formatDateTime(clock.date, Config.use24h ? "HH:mm" : "h:mm AP")
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onContainsMouseChanged: root.showDate = containsMouse
    }
}
