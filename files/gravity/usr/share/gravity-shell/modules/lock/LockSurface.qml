import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.services

// The lock screen. It starts as an exact copy of the desktop (captured just before
// locking), which blurs and sinks back while the blurred wallpaper fades in over it; the
// clock, the date pill and the password pill then float in. Unlocking runs all of that
// back to the sharp desktop, so the real one takes over without a jump.
WlSessionLockSurface {
    id: surface

    required property var lock

    color: Theme.night

    // 0 = the desktop as it was, 1 = the lock screen.
    property real show: 0
    readonly property bool leaving: lock.phase === "unlocking"

    // The desktop capture for this screen, or the wallpaper if there is none.
    readonly property string desktopUrl: {
        const c = surface.screen ? lock.captures[surface.screen.name] : null;
        return c ? c.url.toString() : Media.stillUrl(Config.wallpaperPath);
    }
    readonly property size fullSize: surface.screen ? Qt.size(surface.screen.width * surface.screen.devicePixelRatio, surface.screen.height * surface.screen.devicePixelRatio) : Qt.size(0, 0)

    NumberAnimation on show {
        id: intro
        from: 0
        to: 1
        duration: 700
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.emphasized
    }

    onLeavingChanged: if (leaving) {
        intro.stop();
        outro.start();
    }

    // Ends exactly on the sharp desktop, just as the session lock lets go.
    NumberAnimation {
        id: outro
        target: surface
        property: "show"
        to: 0
        duration: surface.lock.outroDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.emphasized
    }

    // --- background ---------------------------------------------------------------
    // Both layers zoom in slightly as they blur; that also hides the blur's soft edge.
    Item {
        anchors.fill: parent
        scale: 1 + surface.show * 0.05

        Image {
            id: desktop

            anchors.fill: parent
            source: surface.screen ? surface.desktopUrl : ""
            fillMode: Image.PreserveAspectCrop
            // A capture already has the screen's size (and can't be scaled on load).
            sourceSize: surface.desktopUrl.startsWith("file:") ? surface.fullSize : undefined
            // Synchronous: the very first frame must already be the desktop.
            asynchronous: false
            visible: false
        }

        MultiEffect {
            anchors.fill: parent
            source: desktop
            autoPaddingEnabled: false
            blurEnabled: true
            blurMax: 64
            blur: surface.show
        }

        // The wallpaper (a video's poster frame), always blurred, fading in over it.
        Image {
            id: wallpaper

            anchors.fill: parent
            source: surface.screen ? Media.stillUrl(Config.wallpaperPath) : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize: surface.fullSize
            asynchronous: false
            visible: false
        }

        MultiEffect {
            anchors.fill: parent
            source: wallpaper
            autoPaddingEnabled: false
            blurEnabled: true
            blurMax: 64
            blur: 1
            opacity: surface.show
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: surface.show
    }

    // --- content ------------------------------------------------------------------
    Item {
        id: content

        anchors.fill: parent
        // Comes in during the second half of the intro, leaves in the first half of the outro.
        opacity: Math.max(0, surface.show * 2 - 1)
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
            y: surface.height * 0.28 - (1 - surface.show) * 40
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
            anchors.topMargin: 8 - (1 - surface.show) * 20
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
        // Material 3 Expressive: every character pops in as a random shape; while PAM checks
        // the password they wobble and the loading indicator morphs at the end of the pill;
        // a wrong one flashes the outline red and drops the shapes; the right one turns the
        // pill to the accent.
        Item {
            id: entry

            readonly property bool checking: surface.lock.pamActive
            // 1 right after a wrong password, fading to 0.
            property real error: 0

            anchors.horizontalCenter: parent.horizontalCenter
            y: surface.height * 0.64 + (1 - surface.show) * 50
            width: grow.value
            height: Math.round(surface.height * 0.06)

            // Grows with the shapes, on the expressive spring.
            Spring {
                id: grow

                spec: "defaultSpatial"
                to: Math.max(surface.height * 0.3, surface.lock.buffer.length * passwordShapes.shapeSize * 1.45 + entry.height * 2)
                Component.onCompleted: snap(to)
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

            Rectangle {
                id: pill

                anchors.fill: parent
                radius: height / 2
                color: surface.leaving ? Theme.gold : Theme.surface
                border.width: entry.checking ? 3 : entry.error > 0 ? 3 : 0
                border.color: entry.error > 0 ? Qt.alpha(Theme.rose, entry.error) : Theme.gold

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.fast
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                text: "Enter password"
                color: Theme.textDim
                font.family: Theme.font
                font.pixelSize: Math.round(surface.height * 0.017)
                font.weight: Font.Bold
                opacity: surface.lock.buffer.length === 0 && !entry.checking && !passwordShapes.failing ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.fast
                    }
                }
            }

            PasswordShapes {
                id: passwordShapes

                anchors.fill: parent
                anchors.leftMargin: entry.height * 0.5
                anchors.rightMargin: entry.height * 0.5
                count: surface.lock.buffer.length
                checking: entry.checking
                granted: surface.leaving
                shapeSize: Math.round(surface.height * 0.019)
            }

            Connections {
                target: surface.lock

                function onFailed(): void {
                    passwordShapes.fail();
                    errorFade.restart();
                }
            }

            // While PAM checks: the loading indicator, springing in at the end of the pill.
            Spring {
                id: loaderIn

                spec: "fastSpatial"
                to: entry.checking ? 1 : 0
            }

            LoadingIndicator {
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: (entry.height - size) / 2
                size: entry.height * 0.8
                color: Theme.gold
                scale: Math.max(0, loaderIn.value)
                visible: loaderIn.value > 0.01
            }
        }

        // Only for problems: a wrong password or a message from PAM.
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: entry.bottom
            anchors.topMargin: 16
            text: surface.lock.message
            opacity: text !== "" ? 1 : 0
            color: Theme.rose
            font.family: Theme.font
            font.pixelSize: Math.round(surface.height * 0.016)
            font.weight: Font.Bold

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.fast
                }
            }
        }
    }
}
