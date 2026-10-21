import QtQuick
import Quickshell
import qs.services

// niri workspaces on this output as numbered circles, in a row (or a column, along a side).
// They hold still; switching moves a gold pill from the old workspace to the new one, its
// leading edge first and the trailing edge catching up, so it stretches toward where
// you're going and settles.
//   focused   accent pill behind it
//   active    (on another screen) full size, accent outline
//   occupied  tonal fill
//   empty     plain outline
Item {
    id: root

    required property string output
    property bool vertical: false
    readonly property bool hasWorkspaces: Object.keys(Niri.workspaces).length > 0

    // The focused workspace's circle on this output, or null when focus is elsewhere.
    property Item focusedDot: null

    implicitWidth: vertical ? 26 : row.implicitWidth
    implicitHeight: vertical ? row.implicitHeight : 26
    visible: hasWorkspaces

    // --- the focus pill -------------------------------------------------------------
    Rectangle {
        id: pill

        // Its two edges along the row, animated separately.
        property real edgeL: 0
        property real edgeR: 0
        property bool placed: false

        function moveTo(dot: Item): void {
            if (!dot)
                return;
            const l = root.vertical ? dot.y : dot.x;
            const r = l + (root.vertical ? dot.height : dot.width);
            leftAnim.stop();
            rightAnim.stop();
            if (!placed) {
                edgeL = l;
                edgeR = r;
                placed = true;
                return;
            }
            // The edge on the side we're heading to leaves first.
            const forward = l > edgeL;
            leftAnim.to = l;
            leftAnim.duration = forward ? 420 : 220;
            rightAnim.to = r;
            rightAnim.duration = forward ? 220 : 420;
            leftAnim.start();
            rightAnim.start();
        }

        x: root.vertical ? 0 : edgeL
        y: root.vertical ? edgeL : 0
        width: root.vertical ? 26 : edgeR - edgeL
        height: root.vertical ? edgeR - edgeL : 26
        radius: 13
        color: Theme.gold
        opacity: root.focusedDot ? 1 : 0

        NumberAnimation {
            id: leftAnim

            target: pill
            property: "edgeL"
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            id: rightAnim

            target: pill
            property: "edgeR"
            easing.type: Easing.OutCubic
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.fast
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: Theme.normal
            }
        }
    }

    onFocusedDotChanged: pill.moveTo(focusedDot)

    // --- the circles ----------------------------------------------------------------
    Grid {
        id: row

        columns: root.vertical ? 1 : 100
        spacing: 4

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

                // 0..1 as the circle drops into place when it appears.
                property real enter: 0

                function claimFocus(): void {
                    if (focused)
                        root.focusedDot = dot;
                    else if (root.focusedDot === dot)
                        root.focusedDot = null;
                }

                onFocusedChanged: claimFocus()
                Component.onCompleted: claimFocus()
                Component.onDestruction: if (root.focusedDot === dot)
                    root.focusedDot = null
                // Workspaces added or removed shift the circles: keep the pill under its own.
                onXChanged: if (root.focusedDot === dot)
                    pill.moveTo(dot)
                onYChanged: if (root.focusedDot === dot)
                    pill.moveTo(dot)

                width: 26
                height: 26
                radius: width / 2
                opacity: enter
                // The others are a size smaller than the active one.
                scale: (active ? 1 : mouse.containsMouse ? 0.92 : 0.82) * (0.6 + 0.4 * enter)

                // The focused one is drawn by the pill behind it.
                color: !active && windows > 0 ? Theme.tonal : "transparent"
                border.width: focused || (!active && windows > 0) ? 0 : active ? 2 : 1.5
                border.color: active ? Theme.gold : Theme.textDim

                transform: Translate {
                    y: -(1 - dot.enter) * 14
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
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => Niri.action([event.angleDelta.y < 0 ? "focus-workspace-down" : "focus-workspace-up"])
    }
}
