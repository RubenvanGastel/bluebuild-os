import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.services

// The lock screen: the wallpaper, blurred and dimmed, with a bold clock, the date in a
// tonal pill and a solid password pill, in the same style as the bar.
WlSessionLockSurface {
    id: surface

    required property var lock

    color: Theme.night

    // 0 = plain wallpaper, 1 = blurred with the content shown.
    property real show: 0
    readonly property bool leaving: lock.phase === "unlocking"

    // The desktop already shows this wallpaper, so blurring it in reads as a transition.
    NumberAnimation on show {
        id: intro
        from: 0
        to: 1
        duration: Theme.slow
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.settle
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
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.depart
    }

    Image {
        id: wallpaper

        anchors.fill: parent
        // The screen is assigned just after the surface is created; wait for it so the
        // image isn't decoded twice.
        // A video wallpaper shows its poster frame here.
        source: surface.screen ? Media.stillUrl(Config.wallpaperPath) : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize: surface.screen ? Qt.size(surface.screen.width * surface.screen.devicePixelRatio, surface.screen.height * surface.screen.devicePixelRatio) : Qt.size(0, 0)
        // Synchronous so the very first frame already has the picture.
        asynchronous: false
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: wallpaper
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 64
        blur: surface.show
        // Slight zoom hides the soft, see-through edge the blur leaves.
        scale: 1 + surface.show * 0.04
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: surface.show
    }

    Item {
        id: content

        anchors.fill: parent
        opacity: surface.show
        focus: true

        Keys.onPressed: event => {
            surface.lock.handleKey(event);
            event.accepted = true;
        }

        SystemClock {
            id: clock
            precision: SystemClock.Minutes
        }

        Text {
            id: time

            anchors.horizontalCenter: parent.horizontalCenter
            y: surface.height * 0.28 + (1 - surface.show) * 30
            text: Qt.formatDateTime(clock.date, Config.use24h ? "HH:mm" : "h:mm")
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: Math.round(surface.height * 0.14)
            font.weight: Font.Bold

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Theme.night
                shadowBlur: 1
                shadowOpacity: 0.6
                shadowVerticalOffset: 2
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: time.bottom
            anchors.topMargin: 8
            width: date.implicitWidth + height
            height: Math.round(surface.height * 0.045)
            radius: height / 2
            color: Theme.tonal

            Text {
                id: date

                anchors.centerIn: parent
                text: Qt.formatDateTime(clock.date, "dddd d MMMM")
                color: Theme.tonalInk
                font.family: Theme.font
                font.pixelSize: Math.round(surface.height * 0.02)
                font.weight: Font.Bold
            }
        }

        // --- password pill ------------------------------------------------------------
        Item {
            id: entry

            readonly property real dotSize: Math.round(surface.height * 0.012)

            anchors.horizontalCenter: parent.horizontalCenter
            y: surface.height * 0.64 + (1 - surface.show) * 40
            width: Math.max(surface.height * 0.3, dots.width + 48)
            height: Math.round(surface.height * 0.055)

            Behavior on width {
                NumberAnimation {
                    duration: Theme.fast
                    easing.type: Easing.OutCubic
                }
            }

            // Solid surface; an accent ring while the password is checked.
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Theme.surface
                border.width: surface.lock.pamActive ? 3 : 0
                border.color: Theme.gold
            }

            Row {
                id: dots

                anchors.centerIn: parent
                spacing: entry.dotSize * 0.6

                Repeater {
                    model: surface.lock.buffer.length

                    Rectangle {
                        width: entry.dotSize
                        height: entry.dotSize
                        radius: width / 2
                        color: Theme.gold
                        scale: 0
                        Component.onCompleted: scale = 1

                        Behavior on scale {
                            NumberAnimation {
                                duration: 220
                                easing.type: Easing.OutBack
                                easing.overshoot: 3
                            }
                        }
                    }
                }
            }

            // Wrong password: a short shake.
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
            text: surface.lock.message !== "" ? surface.lock.message : surface.lock.pamActive ? "Checking…" : surface.lock.buffer.length > 0 ? "Press Enter" : "Type your password"
            color: surface.lock.message !== "" ? Theme.rose : Theme.text
            font.family: Theme.font
            font.pixelSize: Math.round(surface.height * 0.016)
            font.weight: Font.Bold
        }
    }
}
