import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.services

// Settings (Mod+Comma, the cog in the quick panel, or `gravity-shell ipc call settings
// toggle`). Like the session menu the screen dims and a solid card springs up, with the
// pages in a sidebar: Appearance, Bar, Wi-Fi, Bluetooth and Lock & clock. Changes apply at
// once and are saved in config.json (light or dark in GNOME's own setting). Ctrl+Tab goes
// through the pages; Esc or a click outside closes.
Scope {
    id: root

    // `shown` keeps the window up while the card drops away after `open` goes false.
    property bool open: false
    property bool shown: false
    property var targetScreen: Quickshell.screens[0]
    property string page: "appearance"

    readonly property var pages: [
        { id: "appearance", label: "Appearance", icon: "\u{f03d8}" },
        { id: "bar", label: "Bar", icon: "\u{f06fc}" },
        { id: "wifi", label: "Wi-Fi", icon: "\u{f05a9}" },
        { id: "bluetooth", label: "Bluetooth", icon: "\u{f00af}" },
        { id: "general", label: "Lock & clock", icon: "\u{f097f}" }
    ]

    function show(id: string): void {
        if (pages.some(p => p.id === id))
            page = id;
        if (open)
            return;
        Panels.closeQuick();
        Panels.closeTray();
        Panels.closeMonitor();
        targetScreen = Quickshell.screens.find(s => s.name === (Object.values(Niri.workspaces).find(w => w.is_focused)?.output ?? "")) ?? Quickshell.screens[0];
        shown = true;
        open = true;
    }

    function close(): void {
        open = false;
    }

    function toggle(): void {
        if (open)
            close();
        else
            show("");
    }

    IpcHandler {
        target: "settings"

        function toggle(): void {
            root.toggle();
        }

        // appearance, bar, wifi, bluetooth or general.
        function open(page: string): void {
            root.show(page);
        }
    }

    Connections {
        target: Panels

        function onSettingsRequested(page: string): void {
            root.show(page);
        }
    }

    LazyLoader {
        active: root.shown

        PanelWindow {
            id: win

            screen: root.targetScreen
            color: "transparent"
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "gravity-settings"
            WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            // 0..1: the screen dimming, and the card from below the edge to in place.
            property real fade: 0
            property real rise: 0

            Component.onCompleted: enter.start()

            Connections {
                target: root

                function onOpenChanged(): void {
                    if (root.open) {
                        leave.stop();
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
                    property: "fade"
                    to: 1
                    duration: Theme.normal
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    target: win
                    property: "rise"
                    to: 1
                    duration: 520
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.1
                }
            }

            // Gravity takes it: the card falls away and the screen brightens again.
            SequentialAnimation {
                id: leave

                ParallelAnimation {
                    NumberAnimation {
                        target: win
                        property: "rise"
                        to: 0
                        duration: 300
                        easing.type: Easing.InQuad
                    }
                    NumberAnimation {
                        target: win
                        property: "fade"
                        to: 0
                        duration: 300
                        easing.type: Easing.InQuad
                    }
                }
                ScriptAction {
                    script: root.shown = false
                }
            }

            Rectangle {
                anchors.fill: parent
                color: Theme.night
                opacity: 0.6 * win.fade
            }

            // A click outside the card closes.
            MouseArea {
                anchors.fill: parent
                onClicked: root.close()
            }

            Rectangle {
                id: card

                anchors.horizontalCenter: parent.horizontalCenter
                y: (parent.height - height) / 2 + (1 - win.rise) * (parent.height / 2 + height)
                opacity: Math.min(1, win.rise * 2)
                width: Math.min(900, parent.width - 2 * Theme.gap)
                height: Math.min(640, parent.height - 2 * Theme.gap)
                radius: 40
                color: Theme.surface

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Qt.rgba(0, 0, 0, 0.45)
                    shadowBlur: 0.8
                    shadowVerticalOffset: 6
                }

                // Swallows clicks on the card itself (and takes focus from a field), so they
                // don't close it.
                MouseArea {
                    anchors.fill: parent
                    onClicked: card.forceActiveFocus()
                }

                focus: true
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        root.close();
                    } else if ((event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) && event.modifiers & Qt.ControlModifier) {
                        const n = root.pages.length;
                        const i = root.pages.findIndex(p => p.id === root.page);
                        root.page = root.pages[(i + (event.key === Qt.Key_Backtab ? n - 1 : 1)) % n].id;
                    } else {
                        return;
                    }
                    event.accepted = true;
                }

                // --- the pages ---------------------------------------------------------------
                Column {
                    id: sidebar

                    x: 20
                    y: 28
                    width: 220
                    spacing: 4

                    Text {
                        leftPadding: 16
                        bottomPadding: 14
                        text: "Settings"
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 26
                        font.weight: Font.Bold
                    }

                    Repeater {
                        model: root.pages

                        Rectangle {
                            id: tab

                            required property var modelData
                            readonly property bool selected: root.page === modelData.id

                            width: sidebar.width
                            height: 48
                            radius: selected ? 16 : 24
                            color: selected ? Theme.gold : tabMouse.containsMouse ? Theme.tonal : "transparent"

                            Behavior on radius {
                                NumberAnimation {
                                    duration: Theme.normal
                                    easing.type: Easing.OutBack
                                }
                            }
                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.fast
                                }
                            }

                            Row {
                                x: 16
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 14

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: tab.modelData.icon
                                    color: tab.selected ? Theme.goldInk : Theme.tonalInk
                                    font.family: "Symbols Nerd Font"
                                    font.pixelSize: 20
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: tab.modelData.label
                                    color: tab.selected ? Theme.goldInk : Theme.text
                                    font.family: Theme.font
                                    font.pixelSize: 14
                                    font.weight: Font.Bold
                                }
                            }

                            MouseArea {
                                id: tabMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.page = tab.modelData.id
                            }
                        }
                    }
                }

                // --- the page that is open ---------------------------------------------------
                Rectangle {
                    x: sidebar.x + sidebar.width + 16
                    y: 12
                    width: parent.width - x - 12
                    height: parent.height - 24
                    radius: 30
                    color: Theme.night
                    clip: true

                    Flickable {
                        id: flick

                        anchors.fill: parent
                        anchors.margins: 6
                        contentHeight: pageColumn.implicitHeight + 48
                        boundsBehavior: Flickable.StopAtBounds

                        Column {
                            id: pageColumn

                            x: 24
                            y: 24
                            width: flick.width - 48
                            spacing: 22

                            Text {
                                text: root.pages.find(p => p.id === root.page)?.label ?? ""
                                color: Theme.text
                                font.family: Theme.font
                                font.pixelSize: 22
                                font.weight: Font.Bold
                            }

                            AppearancePage {
                                visible: root.page === "appearance"
                                width: parent.width
                                settings: root
                            }

                            BarPage {
                                visible: root.page === "bar"
                                width: parent.width
                                settings: root
                            }

                            WifiPage {
                                visible: root.page === "wifi"
                                width: parent.width
                                settings: root
                            }

                            BluetoothPage {
                                visible: root.page === "bluetooth"
                                width: parent.width
                                settings: root
                            }

                            GeneralPage {
                                visible: root.page === "general"
                                width: parent.width
                                settings: root
                            }
                        }
                    }

                    // Back to the top on another page.
                    Connections {
                        target: root

                        function onPageChanged(): void {
                            flick.contentY = 0;
                        }
                    }
                }
            }
        }
    }
}
