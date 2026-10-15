import QtQuick
import Quickshell
import qs.services

// niri workspaces on this output as numbered circles floating in the gravity field. Each
// bobs on its own and swings with gravity a moment after its left neighbour, like beads
// on a string.
//   focused   full size, accent fill
//   active    (on another screen) full size, accent outline
//   occupied  tonal fill
//   empty     plain outline
Row {
    id: root

    required property string output

    // Scene time, for the bobbing.
    property real t: 0

    spacing: 4
    visible: Object.keys(Niri.workspaces).length > 0

    FrameAnimation {
        running: root.visible
        onTriggered: root.t += frameTime
    }

    Repeater {
        model: ScriptModel {
            values: Niri.workspaceIdsOn(root.output)
        }

        Rectangle {
            id: dot

            required property int modelData
            required property int index
            readonly property var ws: Niri.workspaces[modelData] ?? null
            readonly property bool active: ws?.is_active ?? false
            readonly property bool focused: ws?.is_focused ?? false
            readonly property int windows: Niri.windowCountOn(modelData)

            // Stable per workspace, so each keeps its own rhythm.
            readonly property real phase: {
                const x = Math.sin(modelData * 12.9898) * 43758.5453;
                return (x - Math.floor(x)) * Math.PI * 2;
            }
            // Each circle feels the field a moment later than the one to its left.
            readonly property point g: root.t, Gravity.active ? Gravity.offsetAt(Gravity.now() - index * 0.07) : Qt.point(0, 0)

            // 0..1 as the circle drops into place when it appears.
            property real enter: 0

            width: 26
            height: 26
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            opacity: enter
            // The others are a size smaller than the active one.
            scale: (active ? 1 : mouse.containsMouse ? 0.92 : 0.82) * (0.6 + 0.4 * enter)

            color: focused ? Theme.gold : !active && windows > 0 ? Theme.tonal : "transparent"
            border.width: focused || (!active && windows > 0) ? 0 : active ? 2 : 1.5
            border.color: active ? Theme.gold : Theme.textDim

            transform: Translate {
                x: dot.g.x * 8
                y: Math.sin(root.t * 1.1 + dot.phase) * 1.5 + dot.g.y * 5 - (1 - dot.enter) * 14
            }

            NumberAnimation on enter {
                from: 0
                to: 1
                duration: Theme.slow
                easing.type: Easing.OutBack
            }

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.normal
                    easing.type: Easing.OutBack
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: Theme.normal
                }
            }

            Text {
                anchors.centerIn: parent
                text: dot.ws?.idx ?? ""
                color: dot.focused ? Theme.goldInk : dot.active ? Theme.gold : dot.windows > 0 ? Theme.tonalInk : Theme.textDim
                font.family: Theme.font
                font.pixelSize: 13
                font.weight: dot.active ? Font.ExtraBold : Font.Bold

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.normal
                    }
                }
            }

            MouseArea {
                id: mouse

                anchors.fill: parent
                anchors.margins: -2
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Niri.focusWorkspace(dot.modelData)
            }
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => Niri.action([event.angleDelta.y < 0 ? "focus-workspace-down" : "focus-workspace-up"])
    }
}
