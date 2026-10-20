import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.components
import qs.services

// Menu of a tray icon (right click), drawn in the shell's own style instead of a plain
// Qt menu. Like the quick panel it is the bar growing into the screen beside the icon,
// flowing into the bar in a curve on each side; submenus open in place with a Back row. Esc, a click
// outside or choosing an entry closes it.
Scope {
    id: root

    readonly property bool open: Panels.trayOutput !== ""
    // Keeps the window up while the card goes away after closing.
    property bool shown: false

    onOpenChanged: if (open)
        shown = true

    LazyLoader {
        active: root.shown

        PanelWindow {
            id: win

            screen: Quickshell.screens.find(s => s.name === Panels.trayOutput) ?? Quickshell.screens[0]
            color: "transparent"
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "gravity-tray-menu"
            WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            // Click-through while it goes away.
            mask: root.open ? null : passThrough

            Region {
                id: passThrough
            }

            // Submenus opened so far; the last is shown. Starts at the app's menu.
            property var stack: [Panels.trayMenu]
            readonly property var current: stack[stack.length - 1] ?? null

            function enter(entry: var): void {
                stack = [...stack, entry];
            }

            function back(): void {
                if (stack.length > 1)
                    stack = stack.slice(0, -1);
            }

            // Another icon's menu while open: start over with that one.
            Connections {
                target: Panels

                function onTrayMenuChanged(): void {
                    win.stack = [Panels.trayMenu];
                }
            }

            // The bar's surface growing down into the menu (0 = just the bar, 1 = full
            // size), and the entries showing in it once there is room. As the quick panel.
            property real grow: 0
            property real reveal: 0

            Component.onCompleted: enter.start()

            Connections {
                target: root

                function onOpenChanged(): void {
                    if (root.open) {
                        leave.stop();
                        win.stack = [Panels.trayMenu];
                        enter.start();
                    } else {
                        enter.stop();
                        leave.start();
                    }
                }
            }

            ParallelAnimation {
                id: enter

                NumberAnimation {
                    target: win
                    property: "grow"
                    to: 1
                    duration: 420
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.emphasized
                }
                SequentialAnimation {
                    PauseAnimation {
                        duration: 140
                    }
                    NumberAnimation {
                        target: win
                        property: "reveal"
                        to: 1
                        duration: 240
                        easing.type: Easing.OutCubic
                    }
                }
            }

            // The reverse: the entries go first, then the surface pulls back up.
            SequentialAnimation {
                id: leave

                ParallelAnimation {
                    NumberAnimation {
                        target: win
                        property: "reveal"
                        to: 0
                        duration: 120
                        easing.type: Easing.InQuad
                    }
                    SequentialAnimation {
                        PauseAnimation {
                            duration: 60
                        }
                        NumberAnimation {
                            target: win
                            property: "grow"
                            to: 0
                            duration: 280
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.depart
                        }
                    }
                }
                ScriptAction {
                    script: root.shown = false
                }
            }

            // Click anywhere else to close.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: Panels.closeTray()
            }

            Item {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: Panels.closeTray()
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Backspace || event.key === Qt.Key_Left) {
                        win.back();
                        event.accepted = true;
                    }
                }
            }

            QsMenuOpener {
                id: opener

                menu: win.current
            }

            // Full height of the menu's surface; a submenu of another size makes it grow
            // or shrink rather than jump.
            property real full: list.implicitHeight + 16

            Behavior on full {
                NumberAnimation {
                    duration: Theme.normal
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.emphasized
                }
            }

            // Its far end just past the icon, kept clear of the bar's ends.
            BarSheet {
                anchors.fill: parent
                align: "end"
                at: Panels.trayAt
                radius: 24
                fullWidth: 280
                fullHeight: win.full
                grow: win.grow

                Column {
                    id: list

                    x: 8
                    y: 8 - (1 - win.reveal) * 10
                    width: parent.width - 16
                    opacity: win.reveal * fade

                    // Fades in again on each new (sub)menu.
                    property real fade: 1
                    Connections {
                        target: win

                        function onCurrentChanged(): void {
                            list.fade = 0;
                            fadeIn.restart();
                        }
                    }
                    NumberAnimation {
                        id: fadeIn

                        target: list
                        property: "fade"
                        to: 1
                        duration: Theme.fast
                    }

                    // Back to the parent menu.
                    Row_ {
                        visible: win.stack.length > 1
                        label: "Back"
                        leading: "\u{f0141}"
                        onClicked: win.back()
                    }

                    Rectangle {
                        visible: win.stack.length > 1
                        width: parent.width
                        height: 9
                        color: "transparent"

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width - 16
                            height: 1
                            color: Qt.alpha(Theme.text, 0.12)
                        }
                    }

                    Repeater {
                        model: opener.children

                        Loader {
                            id: slot

                            required property var modelData

                            width: list.width
                            sourceComponent: modelData.isSeparator ? separator : item

                            Component {
                                id: separator

                                Item {
                                    height: 9

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: parent.width - 16
                                        height: 1
                                        color: Qt.alpha(Theme.text, 0.12)
                                    }
                                }
                            }

                            Component {
                                id: item

                                Row_ {
                                    entry: slot.modelData
                                    label: slot.modelData.text
                                    onClicked: {
                                        if (slot.modelData.hasChildren) {
                                            win.enter(slot.modelData);
                                        } else {
                                            slot.modelData.triggered();
                                            Panels.closeTray();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // One clickable row: optional icon or check mark on the left, the label, and an
    // arrow when it opens a submenu.
    component Row_: Rectangle {
        id: row

        property var entry: null
        property string label
        // Nerd Font glyph in place of an icon (the Back row).
        property string leading: ""
        readonly property bool usable: entry?.enabled ?? true
        readonly property bool checkable: entry && entry.buttonType !== QsMenuButtonType.None
        readonly property bool checked: entry?.checkState === Qt.Checked

        signal clicked

        width: parent?.width ?? 0
        height: 38
        radius: 14
        color: mouse.containsMouse && usable ? Theme.tonal : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: Theme.fast
            }
        }

        Row {
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            opacity: row.usable ? 1 : 0.4

            // Check box or radio button.
            Rectangle {
                visible: row.checkable
                width: 16
                height: 16
                anchors.verticalCenter: parent.verticalCenter
                radius: row.entry?.buttonType === QsMenuButtonType.RadioButton ? 8 : 5
                color: row.checked ? Theme.gold : "transparent"
                border.width: row.checked ? 0 : 1.5
                border.color: Theme.textDim

                Text {
                    anchors.centerIn: parent
                    visible: row.checked
                    text: row.entry?.buttonType === QsMenuButtonType.RadioButton ? "\u{f0765}" : "\u{f012c}"
                    color: Theme.goldInk
                    font.pixelSize: row.entry?.buttonType === QsMenuButtonType.RadioButton ? 8 : 12
                }
            }

            IconImage {
                visible: !row.checkable && (row.entry?.icon ?? "") !== ""
                width: 18
                height: 18
                anchors.verticalCenter: parent.verticalCenter
                source: row.entry?.icon ?? ""
                asynchronous: true
            }

            Text {
                visible: row.leading !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: row.leading
                color: Theme.textDim
                font.pixelSize: 16
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                // Room left of the submenu arrow.
                width: Math.min(implicitWidth, row.width - x - 40)
                elide: Text.ElideRight
                // Mnemonic underscores ("_Quit") aren't shown.
                text: row.label.replace(/_(?!_)/g, "").replace(/__/g, "_")
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
        }

        Text {
            visible: row.entry?.hasChildren ?? false
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: "\u{f0142}"
            color: Theme.textDim
            font.pixelSize: 16
        }

        MouseArea {
            id: mouse

            anchors.fill: parent
            hoverEnabled: true
            enabled: row.usable
            cursorShape: Qt.PointingHandCursor
            onClicked: row.clicked()
        }
    }
}
