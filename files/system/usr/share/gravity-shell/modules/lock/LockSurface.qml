import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.services
import "../../components/Rng.js" as Rng

// The lock screen itself. Its background is the same gravity scene the curtain ends on,
// so the hand-over is invisible; then the clock digits fall into place one by one.
WlSessionLockSurface {
    id: surface

    required property var lock

    color: Theme.night

    // 0 = content gone, 1 = settled. Each digit/gem derives its own staggered progress.
    property real show
    readonly property bool leaving: lock.phase === "unlocking"

    function easeOutBack(x: real): real {
        const c1 = 1.70158, c3 = c1 + 1;
        return 1 + c3 * Math.pow(x - 1, 3) + c1 * Math.pow(x - 1, 2);
    }

    // Staggered progress for the n-th element.
    function stagger(n: int): real {
        return easeOutBack(Rng.clamp(surface.show * 1.6 - n * 0.09, 0, 1));
    }

    NumberAnimation on show {
        id: intro
        from: 0
        to: 1
        duration: 1300
    }

    onLeavingChanged: if (leaving) {
        intro.stop();
        outro.start();
    }

    NumberAnimation {
        id: outro
        target: surface
        property: "show"
        to: 0
        duration: surface.lock.outroDuration
        easing.type: Easing.InQuad
    }

    GravityScene {
        id: scene

        anchors.fill: parent
        ripples: false
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.night
        opacity: surface.lock.dim
    }

    Item {
        id: content

        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            surface.lock.handleKey(event);
            event.accepted = true;
        }

        SystemClock {
            id: clock
            precision: SystemClock.Minutes
        }

        // --- floating clock -------------------------------------------------------------
        Row {
            id: digits

            readonly property string text: Qt.formatDateTime(clock.date, Config.use24h ? "HH:mm" : "h:mm")

            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.3
            spacing: 4

            Repeater {
                model: digits.text.length

                Item {
                    id: digit

                    required property int index
                    readonly property real p: surface.stagger(index)

                    width: glyph.implicitWidth
                    height: glyph.implicitHeight

                    Text {
                        id: glyph

                        text: digits.text.charAt(digit.index)
                        color: Theme.cream
                        font.family: Theme.displayFont
                        font.pixelSize: Math.round(surface.height * 0.13)
                        font.weight: Font.Light
                        // Each digit levitates on its own.
                        y: -(1 - digit.p) * surface.height * 0.35 + Math.sin(scene.t * 0.9 + digit.index * 0.85) * surface.height * 0.006
                        rotation: (1 - digit.p) * (digit.index % 2 ? 14 : -10) + Math.sin(scene.t * 0.6 + digit.index) * 1.2
                        opacity: Rng.clamp(digit.p * 1.4, 0, 1)

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: Theme.nebula
                            shadowBlur: 1
                            shadowOpacity: 0.55
                            shadowVerticalOffset: 0
                            shadowHorizontalOffset: 0
                        }
                    }
                }
            }
        }

        Text {
            id: date

            readonly property real p: surface.stagger(5)

            anchors.horizontalCenter: parent.horizontalCenter
            y: digits.y + digits.height + 8 - (1 - p) * 40
            opacity: Rng.clamp(p, 0, 1)
            text: Qt.formatDateTime(clock.date, "dddd d MMMM")
            color: Theme.textDim
            font.family: Theme.font
            font.pixelSize: Math.round(surface.height * 0.022)
            font.letterSpacing: 2
        }

        // --- password as floating gems ------------------------------------------------
        Item {
            id: entry

            readonly property real p: surface.stagger(7)
            readonly property real gemSize: Math.round(surface.height * 0.022)

            anchors.horizontalCenter: parent.horizontalCenter
            y: surface.height * 0.66 - (1 - p) * 60
            width: Math.max(surface.height * 0.3, gems.width + 48)
            height: entry.gemSize * 2.6
            opacity: Rng.clamp(p, 0, 1)

            // The pill the gems float in.
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Theme.panel
                border.width: 1
                border.color: surface.lock.pamActive ? Theme.gold : Theme.panelBorder

                Behavior on border.color {
                    ColorAnimation {
                        duration: Theme.normal
                    }
                }
            }

            Row {
                id: gems

                anchors.centerIn: parent
                spacing: entry.gemSize * 0.35

                Repeater {
                    model: surface.lock.buffer.length

                    Item {
                        id: gemSlot

                        required property int index

                        width: entry.gemSize
                        height: entry.gemSize

                        Gem {
                            id: gem

                            anchors.centerIn: parent
                            size: entry.gemSize
                            spinning: false
                            scale: 0
                            Component.onCompleted: scale = 1

                            // Bobbing while waiting; tumbling down when the password is wrong.
                            readonly property real fall: surface.lock.fall
                            anchors.verticalCenterOffset: Math.sin(scene.t * 2.4 + gemSlot.index * 0.7) * entry.gemSize * 0.12 + fall * fall * surface.height * (0.35 + (gemSlot.index % 3) * 0.08)
                            rotation: fall * (gemSlot.index % 2 ? 160 : -120)
                            opacity: 1 - fall

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 260
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 3
                                }
                            }
                        }
                    }
                }
            }

            // Wrong password: a short shake before the gems fall.
            SequentialAnimation {
                id: shake

                NumberAnimation {
                    target: entry
                    property: "anchors.horizontalCenterOffset"
                    to: -12
                    duration: 50
                }
                NumberAnimation {
                    target: entry
                    property: "anchors.horizontalCenterOffset"
                    to: 10
                    duration: 70
                }
                NumberAnimation {
                    target: entry
                    property: "anchors.horizontalCenterOffset"
                    to: -6
                    duration: 70
                }
                NumberAnimation {
                    target: entry
                    property: "anchors.horizontalCenterOffset"
                    to: 0
                    duration: 90
                    easing.type: Easing.OutBack
                }
            }

            Connections {
                target: surface.lock
                function onFailed(): void {
                    shake.restart();
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: entry.bottom
            anchors.topMargin: 16
            opacity: entry.opacity * 0.9
            text: surface.lock.message !== "" ? surface.lock.message : surface.lock.pamActive ? "Shifting gravity…" : surface.lock.buffer.length > 0 ? "Press Enter" : "Type your password"
            color: surface.lock.message !== "" ? Theme.rose : Theme.textDim
            font.family: Theme.font
            font.pixelSize: Math.round(surface.height * 0.015)
            font.letterSpacing: 1
        }
    }
}
