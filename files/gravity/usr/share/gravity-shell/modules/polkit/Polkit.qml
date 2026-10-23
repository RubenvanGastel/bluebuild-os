import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit
import Quickshell.Wayland
import qs.components
import qs.services

// Polkit agent: when an app asks for an administrator password (mounting a disk, installing
// updates, changing a system setting, `pkexec`, ...), the screen dims and a card springs up
// from below, as the session menu does, on the focused screen. Material 3 Expressive, like
// the lock screen: the password goes in a pill of dots, the loading indicator morphs while
// it is checked, and the buttons are a connected group. Enter authenticates, Esc or a click outside cancels.
// `gravity-shell ipc call polkit cancel` cancels the open request.
Scope {
    id: root

    PolkitAgent {
        id: agent
    }

    // `shown` keeps the window up while the card drops away after the request ends.
    property bool shown: false
    property bool open: false
    property var targetScreen: Quickshell.screens[0]
    // Kept from the request, so the card still shows them while it falls away.
    property string message
    property string user
    // Turns the pill to the accent once the password was right.
    property bool granted: false

    readonly property var flow: agent.flow

    // The request's details come with its flow, which may be set after the agent turns
    // active.
    onFlowChanged: {
        if (!flow)
            return;
        message = flow.message;
        user = flow.selectedIdentity?.displayName ?? "";
    }

    Connections {
        target: agent

        function onIsActiveChanged(): void {
            if (agent.isActive)
                root.start();
            else
                root.open = false;
        }
    }

    function start(): void {
        Panels.closeQuick();
        Panels.closeTray();
        Panels.closeMonitor();
        Panels.closeBattery();
        Panels.closeMedia();
        targetScreen = Quickshell.screens.find(s => s.name === (Object.values(Niri.workspaces).find(w => w.is_focused)?.output ?? "")) ?? Quickshell.screens[0];
        granted = false;
        shown = true;
        open = true;
    }

    function submit(value: string): void {
        if (flow?.isResponseRequired && value !== "")
            flow.submit(value);
    }

    function cancel(): void {
        if (flow && !flow.isCompleted)
            flow.cancelAuthenticationRequest();
        open = false;
    }

    IpcHandler {
        target: "polkit"

        function cancel(): void {
            root.cancel();
        }

        // Whether a request is open.
        function get(): bool {
            return agent.isActive;
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
            WlrLayershell.namespace: "gravity-polkit"
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
                    easing.overshoot: 1.3
                }
            }

            // Gravity takes it, a moment later when the password was right so the accent
            // pill shows.
            SequentialAnimation {
                id: leave

                PauseAnimation {
                    duration: root.granted ? 250 : 0
                }
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

            // A click outside the card cancels.
            MouseArea {
                anchors.fill: parent
                onClicked: root.cancel()
            }

            Rectangle {
                id: card

                readonly property bool checking: root.open && !!root.flow && !root.flow.isResponseRequired && !root.flow.isCompleted

                anchors.horizontalCenter: parent.horizontalCenter
                y: (parent.height - height) / 2 + (1 - win.rise) * (parent.height / 2 + height)
                opacity: Math.min(1, win.rise * 2)
                width: 440
                height: column.height + 56
                radius: 40
                color: Theme.surface

                Behavior on height {
                    NumberAnimation {
                        duration: Theme.normal
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.5
                    }
                }

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Qt.rgba(0, 0, 0, 0.45)
                    shadowBlur: 0.8
                    shadowVerticalOffset: 6
                }

                // Swallows clicks on the card itself, so they don't cancel.
                MouseArea {
                    anchors.fill: parent
                }

                Column {
                    id: column

                    x: 32
                    y: 28
                    width: parent.width - 64
                    spacing: 16

                    // The lock on a 9-sided cookie that slowly turns; while the password is
                    // checked it gives way to the loading indicator, and the right password
                    // pops it into an accent sunny with a tick.
                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 80
                        height: 80

                        Spring {
                            id: badge

                            spec: "fastSpatial"
                            to: card.checking ? 0 : 1
                            Component.onCompleted: snap(to)
                        }

                        Spring {
                            id: loaderIn

                            spec: "fastSpatial"
                            to: card.checking ? 1 : 0
                        }

                        Connections {
                            target: root

                            function onGrantedChanged(): void {
                                if (root.granted)
                                    badge.kick(5);
                            }
                        }

                        MaterialShape {
                            anchors.fill: parent
                            shape: root.granted ? "sunny" : "cookie9Sided"
                            color: root.granted ? Theme.gold : Theme.tonal
                            scale: Math.max(0, badge.value)

                            NumberAnimation on rotation {
                                from: 0
                                to: 360
                                duration: 20000
                                loops: Animation.Infinite
                                running: win.visible
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.fast
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: root.granted ? "\u{f012c}" : "\u{f033e}"
                            color: root.granted ? Theme.goldInk : Theme.tonalInk
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 30
                            scale: Math.max(0, badge.value)
                        }

                        LoadingIndicator {
                            anchors.centerIn: parent
                            size: 80
                            color: Theme.gold
                            scale: Math.max(0, loaderIn.value)
                            visible: loaderIn.value > 0.01
                        }
                    }

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: "Authentication required"
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 22
                        font.weight: Font.Bold
                    }

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        text: root.message
                        color: Theme.textDim
                        font.family: Theme.font
                        font.pixelSize: 15
                    }

                    // Whose password: polkit picks an administrator, usually you.
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: root.user !== ""
                        width: who.implicitWidth + 28
                        height: 30
                        radius: 15
                        color: Theme.tonal

                        Text {
                            id: who

                            anchors.centerIn: parent
                            text: "\u{f0004}  " + root.user
                            color: Theme.tonalInk
                            font.family: Theme.font
                            font.pixelSize: 13
                            font.weight: Font.Bold
                        }
                    }

                    // --- password pill ----------------------------------------------------
                    // As the lock screen's: dots drop in as you type, a wave runs through them
                    // while the password is checked, and a wrong one shakes the pill.
                    Item {
                        id: entry

                        // 1 right after a wrong password, fading to 0.
                        property real error: 0

                        width: parent.width
                        height: 56

                        transform: Translate {
                            id: shakeMove
                        }

                        // Wrong password: a short shake.
                        SequentialAnimation {
                            id: shake

                            NumberAnimation {
                                target: shakeMove
                                property: "x"
                                to: -14
                                duration: 50
                            }
                            NumberAnimation {
                                target: shakeMove
                                property: "x"
                                to: 12
                                duration: 70
                            }
                            NumberAnimation {
                                target: shakeMove
                                property: "x"
                                to: -7
                                duration: 70
                            }
                            NumberAnimation {
                                target: shakeMove
                                property: "x"
                                to: 0
                                duration: 110
                                easing.type: Easing.OutBack
                            }
                        }

                        NumberAnimation {
                            id: errorFade

                            target: entry
                            property: "error"
                            from: 1
                            to: 0
                            duration: 1100
                            easing.type: Easing.InQuad
                        }

                        Connections {
                            target: root.flow
                            ignoreUnknownSignals: true

                            function onFailedChanged(): void {
                                if (root.flow?.failed) {
                                    shake.restart();
                                    errorFade.restart();
                                    input.text = "";
                                }
                            }
                            function onIsSuccessfulChanged(): void {
                                if (root.flow?.isSuccessful)
                                    root.granted = true;
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: root.granted ? Theme.gold : Theme.deep
                            border.width: card.checking || entry.error > 0 || input.activeFocus ? 3 : 0
                            border.color: entry.error > 0 ? Qt.alpha(Theme.rose, entry.error) : Theme.gold

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.fast
                                }
                            }
                        }

                        // Polkit's own prompt ("Password:"), while nothing is typed.
                        Text {
                            anchors.centerIn: parent
                            text: (root.flow?.inputPrompt ?? "").replace(/:\s*$/, "") || "Password"
                            color: Theme.textDim
                            font.family: Theme.font
                            font.pixelSize: 15
                            font.weight: Font.Bold
                            opacity: input.text.length === 0 && !card.checking ? 1 : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.fast
                                }
                            }
                        }

                        // Takes the typing; shown itself only when polkit asks for something
                        // that may be seen (not a password).
                        TextInput {
                            id: input

                            anchors.fill: parent
                            anchors.leftMargin: 24
                            anchors.rightMargin: 24
                            verticalAlignment: TextInput.AlignVCenter
                            horizontalAlignment: TextInput.AlignHCenter
                            focus: root.open
                            enabled: !card.checking && !root.granted
                            opacity: root.flow?.responseVisible ? 1 : 0
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: 16
                            echoMode: root.flow?.responseVisible ? TextInput.Normal : TextInput.Password
                            selectionColor: Theme.gold
                            selectedTextColor: Theme.goldInk

                            onActiveFocusChanged: if (!activeFocus && root.open)
                                forceActiveFocus()

                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    root.submit(input.text);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Escape) {
                                    root.cancel();
                                    event.accepted = true;
                                }
                            }
                        }

                        PasswordDots {
                            anchors.centerIn: parent
                            visible: !root.flow?.responseVisible
                            count: input.text.length
                            checking: card.checking
                            dotSize: 12
                            color: root.granted ? Theme.goldInk : Theme.gold
                        }
                    }

                    // Polkit's messages: a wrong password in red, anything else dim.
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        visible: text !== ""
                        text: root.flow?.supplementaryMessage ?? ""
                        color: root.flow?.supplementaryIsError ? Theme.rose : Theme.textDim
                        font.family: Theme.font
                        font.pixelSize: 14
                        font.weight: Font.Bold
                    }

                    // Material 3 Expressive button group: a pressed button squares its corners
                    // and grows, pushing its neighbour narrower, all on the fast spatial
                    // spring.
                    Item {
                        id: buttons

                        // Which one is held down ("" = none).
                        property string pressed: ""

                        width: parent.width
                        height: 56

                        Repeater {
                            model: [
                                { id: "cancel", label: "Cancel", accent: false },
                                { id: "ok", label: "Authenticate", accent: true }
                            ]

                            Item {
                                id: button

                                required property var modelData
                                required property int index
                                readonly property bool down: buttons.pressed === modelData.id
                                readonly property bool usable: !modelData.accent || (input.text.length > 0 && !card.checking)
                                readonly property real gap: 8

                                // Share of the row: half each, more for the pressed one.
                                Spring {
                                    id: share

                                    spec: "fastSpatial"
                                    to: buttons.pressed === "" ? 0.5 : button.down ? 0.58 : 0.42
                                    Component.onCompleted: snap(to)
                                }

                                // Fully round at rest, 12 px corners while pressed (the pressed
                                // shape of a 56 px button).
                                Spring {
                                    id: corner

                                    spec: "fastSpatial"
                                    to: button.down ? 12 : 28
                                    Component.onCompleted: snap(to)
                                }

                                x: index === 0 ? 0 : buttons.width * (1 - share.value) + gap / 2
                                width: buttons.width * share.value - gap / 2
                                height: buttons.height

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Math.max(0, corner.value)
                                    color: button.modelData.accent ? (buttonMouse.containsMouse ? Theme.hover(Theme.gold, 1.12) : Theme.gold) : buttonMouse.containsMouse ? Theme.dusk : Theme.tonal
                                    opacity: button.usable ? 1 : 0.5

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: Theme.fast
                                        }
                                    }
                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: Theme.fast
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: button.modelData.label
                                        color: button.modelData.accent ? Theme.goldInk : Theme.tonalInk
                                        font.family: Theme.font
                                        font.pixelSize: 16
                                        font.weight: Font.Bold
                                    }
                                }

                                MouseArea {
                                    id: buttonMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: button.usable ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onPressed: if (button.usable)
                                        buttons.pressed = button.modelData.id
                                    onReleased: buttons.pressed = ""
                                    onCanceled: buttons.pressed = ""
                                    onClicked: if (button.usable)
                                        button.modelData.accent ? root.submit(input.text) : root.cancel()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
