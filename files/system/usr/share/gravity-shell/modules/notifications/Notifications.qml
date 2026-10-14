import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import qs.services

// Notification daemon. Cards drift in from the right and hover; when they expire or are
// dismissed, gravity takes them and they fall off the screen.
Scope {
    id: root

    NotificationServer {
        id: server

        keepOnReload: true
        actionsSupported: true
        imageSupported: true
        bodyMarkupSupported: true

        onNotification: n => {
            n.tracked = true;
            // A small nudge of the gravity field for every arrival.
            if (!Gravity.hold)
                Gravity.kick(-0.25, 0.15, 0.6);
        }
    }

    // Shown on the focused output only (niri), otherwise on the first screen.
    PanelWindow {
        id: win

        screen: Quickshell.screens.find(s => s.name === (Object.values(Niri.workspaces).find(w => w.is_focused)?.output ?? "")) ?? Quickshell.screens[0]
        visible: server.trackedNotifications.values.length > 0
        color: "transparent"
        anchors {
            top: true
            right: true
        }
        margins {
            top: 58
            right: 12
        }
        implicitWidth: 400
        implicitHeight: Math.max(1, stack.implicitHeight + 40)
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "gravity-notifications"
        mask: Region {
            item: stack
        }

        Column {
            id: stack

            x: 20
            width: parent.width - 40
            spacing: 10

            move: Transition {
                NumberAnimation {
                    properties: "y"
                    duration: Theme.slow
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.2
                }
            }

            Repeater {
                model: ScriptModel {
                    values: [...server.trackedNotifications.values].reverse()
                }

                NotificationCard {
                    required property Notification modelData

                    notification: modelData
                    width: stack.width
                }
            }
        }
    }
}
