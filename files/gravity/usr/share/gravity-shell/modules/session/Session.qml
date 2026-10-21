import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.services

// Session menu (`gravity-shell ipc call session toggle`, Mod+Shift+Q).
// The screen dims and a solid card springs up from below with round buttons for lock,
// suspend, log out, reboot, reboot into the firmware setup (when the machine has one) and
// power off. Left/Right (or Tab) picks one, which morphs into an accent square, Enter or a
// click runs it, Esc or a click outside closes. The number keys 1-6 pick one and count down
// for a few seconds first, so a mispress can be undone: Enter runs it right away, Esc or any
// other key cancels.
Scope {
    id: root

    // `shown` keeps the window up while the card drops away after `open` goes false.
    property bool open: false
    property bool shown: false
    property var targetScreen: Quickshell.screens[0]
    property int index: 0
    // Runs once the window is gone, so the lock screen doesn't capture the menu.
    property var pending: null

    // Action counting down after a number key ("" = none), and how far along (0..1).
    property string countdown: ""
    property real countdownProgress: 0
    readonly property int countdownSeconds: 3
    // What the counting action does ("Rebooting"); kept after a cancel while the hint fades.
    property string countdownText
    readonly property int secondsLeft: Math.ceil((1 - countdownProgress) * countdownSeconds)

    // logind says whether the firmware takes "reboot into setup" (UEFI only).
    property bool firmwareSetup: false

    readonly property var allActions: [
        { id: "lock", doing: "Locking", label: "Lock", icon: "\u{f033e}", command: ["gravity-shell", "lock"] },
        // Locks first, so the session is locked when it wakes up.
        { id: "suspend", doing: "Suspending", label: "Suspend", icon: "\u{f0904}", command: ["sh", "-c", "gravity-shell lock; sleep 1; systemctl suspend"] },
        { id: "logout", doing: "Logging out", label: "Log out", icon: "\u{f0343}", command: ["niri", "msg", "action", "quit", "--skip-confirmation"] },
        { id: "reboot", doing: "Rebooting", label: "Reboot", icon: "\u{f0709}", command: ["systemctl", "reboot"] },
        { id: "firmware", doing: "Rebooting into the BIOS", label: "BIOS", icon: "\u{f061a}", command: ["systemctl", "reboot", "--firmware-setup"] },
        { id: "poweroff", doing: "Powering off", label: "Power off", icon: "\u{f0425}", command: ["systemctl", "poweroff"] }
    ]
    readonly property var actions: allActions.filter(a => a.id !== "firmware" || firmwareSetup)

    function toggle(): void {
        if (open) {
            open = false;
            return;
        }
        Panels.closeQuick();
        Panels.closeTray();
        Panels.closeMonitor();
        targetScreen = Quickshell.screens.find(s => s.name === (Object.values(Niri.workspaces).find(w => w.is_focused)?.output ?? "")) ?? Quickshell.screens[0];
        // Starts on Lock, the one that can't lose any work.
        index = 0;
        pending = null;
        cancelCountdown();
        shown = true;
        open = true;
    }

    // Closing (Esc, a click outside, Mod+Shift+Q) cancels a countdown.
    onOpenChanged: if (!open)
        cancelCountdown()

    function startCountdown(i: int): void {
        index = i;
        countdownText = actions[i].doing;
        countdown = actions[i].id;
        countdownAnim.restart();
    }

    function cancelCountdown(): void {
        countdownAnim.stop();
        countdown = "";
        countdownProgress = 0;
    }

    // Only emits `finished` when it runs out, not when it is stopped.
    NumberAnimation {
        id: countdownAnim

        target: root
        property: "countdownProgress"
        from: 0
        to: 1
        duration: root.countdownSeconds * 1000
        onFinished: root.run(root.countdown)
    }

    function run(id: string): void {
        cancelCountdown();
        const action = actions.find(a => a.id === id);
        if (!action)
            return;
        if (!shown) {
            Quickshell.execDetached(action.command);
            return;
        }
        pending = action.command;
        open = false;
    }

    function closed(): void {
        shown = false;
        if (pending) {
            Quickshell.execDetached(pending);
            pending = null;
        }
    }

    Process {
        running: true
        command: ["busctl", "call", "org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager", "CanRebootToFirmwareSetup"]
        stdout: StdioCollector {
            onStreamFinished: root.firmwareSetup = /"(yes|challenge)"/.test(text)
        }
    }

    IpcHandler {
        target: "session"

        function toggle(): void {
            root.toggle();
        }

        // lock, suspend, logout, reboot, firmware or poweroff.
        function run(action: string): void {
            root.run(action);
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
            WlrLayershell.namespace: "gravity-session"
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
                    script: root.closed()
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
                onClicked: root.open = false
            }

            Rectangle {
                id: card

                anchors.horizontalCenter: parent.horizontalCenter
                y: (parent.height - height) / 2 + (1 - win.rise) * (parent.height / 2 + height)
                opacity: Math.min(1, win.rise * 2)
                width: row.width + 48
                // Grows a line for the countdown hint.
                height: row.height + 48 + (root.countdown !== "" ? 30 : 0)
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

                // Swallows clicks on the card itself, so they don't close it.
                MouseArea {
                    anchors.fill: parent
                }

                focus: true
                Keys.onPressed: event => {
                    const n = root.actions.length;
                    const number = event.key - Qt.Key_1;
                    const confirm = event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space;
                    if (event.isAutoRepeat) {
                        // Holding a key down neither cancels nor restarts a countdown.
                    } else if (number >= 0 && number < n) {
                        root.startCountdown(number);
                    } else if (root.countdown !== "") {
                        // Counting down: Enter runs it now, any other key cancels.
                        if (confirm)
                            root.run(root.countdown);
                        else
                            root.cancelCountdown();
                    } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
                        root.index = (root.index + 1) % n;
                    } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) {
                        root.index = (root.index + n - 1) % n;
                    } else if (confirm) {
                        root.run(root.actions[root.index].id);
                    } else if (event.key === Qt.Key_Escape) {
                        root.open = false;
                    } else {
                        return;
                    }
                    event.accepted = true;
                }

                Row {
                    id: row

                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 24
                    spacing: 16

                    Repeater {
                        model: root.actions

                        Item {
                            id: button

                            required property var modelData
                            required property int index
                            readonly property bool selected: root.index === index
                            readonly property bool counting: root.countdown === modelData.id

                            width: 96
                            height: 132

                            // The buttons rise one after another behind the card, as if
                            // each feels the pull a moment later.
                            transform: Translate {
                                y: (1 - Math.max(0, Math.min(1, win.rise * 1.6 - button.index * 0.1))) * 40
                            }

                            Rectangle {
                                id: shape

                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 4
                                width: 88
                                height: 88
                                // Circle when idle; selected, it morphs into a rounded
                                // square in the accent colour, and back into a circle inside
                                // the countdown ring.
                                radius: button.selected && !button.counting ? 28 : 44
                                color: button.selected ? Theme.gold : hover.containsMouse ? Theme.dusk : Theme.tonal
                                scale: hover.pressed ? 0.92 : button.counting ? 0.94 : button.selected ? 1.06 : 1

                                Behavior on radius {
                                    NumberAnimation {
                                        duration: Theme.normal
                                        easing.type: Easing.OutBack
                                        easing.overshoot: 2
                                    }
                                }
                                Behavior on color {
                                    ColorAnimation {
                                        duration: Theme.fast
                                    }
                                }
                                Behavior on scale {
                                    NumberAnimation {
                                        duration: Theme.normal
                                        easing.type: Easing.OutBack
                                        easing.overshoot: 3
                                    }
                                }

                                // The icon, or the seconds left while counting down.
                                Text {
                                    anchors.centerIn: parent
                                    text: button.counting ? root.secondsLeft : button.modelData.icon
                                    color: button.selected ? Theme.goldInk : Theme.tonalInk
                                    font.family: button.counting ? Theme.font : "Symbols Nerd Font"
                                    font.pixelSize: button.counting ? 38 : 34
                                    font.weight: Font.Bold

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: Theme.fast
                                        }
                                    }
                                }
                            }

                            // Countdown ring around the circle, running out clockwise.
                            Shape {
                                anchors.centerIn: shape
                                width: 104
                                height: 104
                                visible: button.counting
                                preferredRendererType: Shape.CurveRenderer

                                ShapePath {
                                    strokeColor: Theme.gold
                                    strokeWidth: 4
                                    fillColor: "transparent"
                                    capStyle: ShapePath.RoundCap

                                    PathAngleArc {
                                        centerX: 52
                                        centerY: 52
                                        radiusX: 50
                                        radiusY: 50
                                        startAngle: -90
                                        sweepAngle: 360 * (1 - root.countdownProgress)
                                    }
                                }
                            }

                            // Its number key, in a chip on the circle's shoulder.
                            Rectangle {
                                x: shape.x + shape.width - width + 4
                                y: shape.y - 4
                                width: 28
                                height: 28
                                radius: 14
                                color: button.selected ? Theme.gold : Theme.dusk
                                border.width: 3
                                border.color: Theme.surface
                                opacity: button.counting ? 0 : 1

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
                                    text: button.index + 1
                                    color: button.selected ? Theme.goldInk : Theme.textDim
                                    font.family: Theme.font
                                    font.pixelSize: 13
                                    font.weight: Font.Bold
                                }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                text: button.modelData.label
                                color: button.selected ? Theme.text : Theme.textDim
                                font.family: Theme.font
                                font.pixelSize: 15
                                font.weight: Font.Bold

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Theme.fast
                                    }
                                }
                            }

                            MouseArea {
                                id: hover

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                // Not while counting down: the countdown keeps its button.
                                onEntered: if (root.countdown === "")
                                    root.index = button.index
                                onClicked: root.run(button.modelData.id)
                            }
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: row.bottom
                    anchors.topMargin: 14
                    text: root.countdownText + " in " + root.secondsLeft + " · Enter now · Esc cancels"
                    color: Theme.textDim
                    font.family: Theme.font
                    font.pixelSize: 15
                    font.weight: Font.Bold
                    opacity: root.countdown !== "" ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.fast
                        }
                    }
                }
            }
        }
    }
}
