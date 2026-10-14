import QtQuick
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import qs.services

// Status-notifier tray. Left click activates, right click opens the app's menu.
Row {
    id: root

    required property var barWindow

    spacing: 8

    Repeater {
        model: SystemTray.items

        Item {
            id: entry

            required property SystemTrayItem modelData

            width: 18
            height: 18
            anchors.verticalCenter: parent.verticalCenter
            scale: 0

            Component.onCompleted: scale = 1

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.slow
                    easing.type: Easing.OutBack
                    easing.overshoot: 2
                }
            }

            IconImage {
                anchors.fill: parent
                source: entry.modelData.icon
                asynchronous: true
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    if (mouse.button === Qt.LeftButton && !entry.modelData.onlyMenu) {
                        entry.modelData.activate();
                    } else if (mouse.button === Qt.MiddleButton) {
                        entry.modelData.secondaryActivate();
                    } else if (entry.modelData.hasMenu) {
                        const p = entry.mapToItem(null, 0, entry.height + 10);
                        entry.modelData.display(root.barWindow, p.x, p.y);
                    }
                }
                onWheel: wheel => entry.modelData.scroll(wheel.angleDelta.y, false)
            }
        }
    }
}
