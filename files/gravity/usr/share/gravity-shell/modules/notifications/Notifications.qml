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

        onNotification: n => n.tracked = true
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
        // In the top right corner, tucked into the bar's curved corner when it is at the top
        // or the right: the cards sit Theme.gap from the bar and the screen edges. The window
        // starts at the bar and reaches a bit further left and down than the cards, for their
        // shadow and the slide-in. Ignore the bar's reserved space, so the margins are exact.
        exclusionMode: ExclusionMode.Ignore
        margins.top: Theme.barEdge === "top" ? Theme.barOuter : Theme.frameSize
        margins.right: Theme.barEdge === "right" ? Theme.barOuter : Theme.frameSize
        implicitWidth: cardWidth + Theme.gap + 40
        implicitHeight: Math.max(1, stack.implicitHeight + below + Theme.gap + 40)
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "gravity-notifications"

        readonly property int cardWidth: 360
        // Room for the quick panel when it is open on this screen: the cards go under it.
        readonly property real below: Panels.quick !== "" && Panels.quick === screen?.name ? Panels.quickHeight + Theme.gap : 0
        mask: Region {
            item: stack
        }

        // Cards are see-through with blur on; niri blurs behind each. Regions can't come from
        // the Repeater, so the first eight cards get one, more than ever fit on the screen.
        readonly property var cards: Array.from(stack.children).filter(c => c.notification !== undefined)

        BackgroundEffect.blurRegion: Region {
            CardRegion {
                card: win.cards[0] ?? null
            }
            CardRegion {
                card: win.cards[1] ?? null
            }
            CardRegion {
                card: win.cards[2] ?? null
            }
            CardRegion {
                card: win.cards[3] ?? null
            }
            CardRegion {
                card: win.cards[4] ?? null
            }
            CardRegion {
                card: win.cards[5] ?? null
            }
            CardRegion {
                card: win.cards[6] ?? null
            }
            CardRegion {
                card: win.cards[7] ?? null
            }
        }

        component CardRegion: Region {
            property Item card

            item: Theme.blur ? card : null
            radius: 24
        }

        Column {
            id: stack

            x: parent.width - width - Theme.gap
            y: Theme.gap + win.below
            width: win.cardWidth

            // Along with the panel growing out of the bar and back.
            Behavior on y {
                NumberAnimation {
                    duration: 420
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.emphasized
                }
            }
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
