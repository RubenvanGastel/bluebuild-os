import QtQuick
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import qs.services

// Status-notifier tray. Left click activates, right click opens the app's menu. Apps
// with nothing to activate (AppIndicator icons such as Steam's) open the menu on a left
// click too.
Row {
    id: root

    required property var barWindow

    // Ids of the tray items that answer Activate, as found on D-Bus; until the check is
    // done, every item is assumed to.
    property var canActivate: null

    spacing: 8

    readonly property int itemCount: SystemTray.items.values.length
    onItemCountChanged: probe.running = true
    Component.onCompleted: probe.running = true

    // For each registered item: its Id, if its interface has an Activate method.
    Process {
        id: probe

        command: ["sh", "-c", `
            busctl --user get-property org.kde.StatusNotifierWatcher /StatusNotifierWatcher \\
                org.kde.StatusNotifierWatcher RegisteredStatusNotifierItems 2>/dev/null |
            grep -o '"[^"]*"' | tr -d '"' | while read -r item; do
                case "$item" in
                    */*) svc="\${item%%/*}"; path="/\${item#*/}" ;;
                    *) svc="$item"; path=/StatusNotifierItem ;;
                esac
                busctl --user introspect "$svc" "$path" org.kde.StatusNotifierItem 2>/dev/null |
                    grep -q '^\\.Activate ' || continue
                busctl --user get-property "$svc" "$path" org.kde.StatusNotifierItem Id 2>/dev/null |
                    sed -n 's/^s "\\(.*\\)"$/\\1/p'
            done
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const ids = {};
                text.split("\n").filter(l => l !== "").forEach(id => ids[id] = true);
                root.canActivate = ids;
            }
        }
    }

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
                    const activates = !entry.modelData.onlyMenu && (root.canActivate?.[entry.modelData.id] ?? true);
                    if (mouse.button === Qt.LeftButton && (activates || !entry.modelData.hasMenu)) {
                        entry.modelData.activate();
                    } else if (mouse.button === Qt.MiddleButton) {
                        entry.modelData.secondaryActivate();
                    } else if (entry.modelData.hasMenu) {
                        // The menu grows down out of the bar, its right edge just past the icon.
                        const p = entry.mapToItem(null, entry.width, 0);
                        const output = root.barWindow.screen?.name ?? "";
                        if (Panels.trayOutput === output && Panels.trayMenu === entry.modelData.menu)
                            Panels.closeTray();
                        else
                            Panels.openTray(output, entry.modelData.menu, p.x + 12);
                    }
                }
                onWheel: wheel => entry.modelData.scroll(wheel.angleDelta.y, false)
            }
        }
    }
}
