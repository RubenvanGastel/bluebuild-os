import QtQuick
import Quickshell
import qs.services

// niri workspaces on this output as orbs. The active one stretches into a gold pill
// with a little mote orbiting it; occupied ones glow violet; the spare empty one is a ring.
Row {
    id: root

    required property string output

    spacing: 7
    visible: Object.keys(Niri.workspaces).length > 0

    Repeater {
        model: ScriptModel {
            values: Niri.workspaceIdsOn(root.output)
        }

        Item {
            id: orb

            required property int modelData
            readonly property var ws: Niri.workspaces[modelData] ?? null
            readonly property bool active: ws?.is_active ?? false
            readonly property bool focused: ws?.is_focused ?? false
            readonly property int windows: Niri.windowCountOn(modelData)

            width: active ? 30 : 12
            height: 12
            anchors.verticalCenter: parent.verticalCenter
            scale: mouse.containsMouse && !active ? 1.25 : 1
            opacity: 0

            Component.onCompleted: opacity = 1

            Behavior on width {
                SpringAnimation {
                    spring: 4
                    damping: 0.32
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: Theme.fast
                    easing.type: Easing.OutBack
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.normal
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: orb.active ? Theme.gold : orb.windows > 0 ? Qt.rgba(Theme.glow.r, Theme.glow.g, Theme.glow.b, 0.75) : "transparent"
                border.width: !orb.active && orb.windows === 0 ? 1.5 : 0
                border.color: Theme.textDim
                gradient: orb.active ? activeGradient : null

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.normal
                    }
                }

                Gradient {
                    id: activeGradient
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0
                        color: Theme.amber
                    }
                    GradientStop {
                        position: 1
                        color: Theme.gold
                    }
                }
            }

            // Orbiting mote around the focused workspace.
            Item {
                anchors.centerIn: parent
                width: orb.width + 10
                height: orb.height + 8
                visible: orb.focused
                opacity: orb.focused ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.normal
                    }
                }

                Rectangle {
                    id: mote

                    property real a: 0

                    width: 3.5
                    height: 3.5
                    radius: 2
                    color: Theme.cream
                    x: parent.width / 2 + Math.cos(a) * parent.width / 2 - width / 2
                    y: parent.height / 2 + Math.sin(a) * parent.height / 2 - height / 2

                    NumberAnimation on a {
                        running: orb.focused
                        loops: Animation.Infinite
                        from: 0
                        to: Math.PI * 2
                        duration: 2600
                    }
                }
            }

            MouseArea {
                id: mouse

                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Niri.focusWorkspace(orb.modelData)
            }
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => Niri.action([event.angleDelta.y < 0 ? "focus-workspace-down" : "focus-workspace-up"])
    }
}
