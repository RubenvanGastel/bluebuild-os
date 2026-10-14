import QtQuick
import qs.services

// The full floating-city field. Used by the wallpaper, the lock curtain and the lock
// screen. All motion is a pure function of Gravity.now(), so two instances on the same
// screen always show the same frame.
Item {
    id: field

    // Seconds since shell start, and the current gravity offset (roughly -1..1).
    property real t: Gravity.now()
    property point g: Qt.point(0, 0)
    // 0 = debris still below the screen, 1 = settled. Only the wallpaper animates this.
    property real intro: 1
    readonly property real rise: Math.pow(1 - intro, 2)
    // Draw gravity ripples when the field is kicked.
    property bool ripples: true

    clip: true

    // The idle drift is slow, so it updates at half the display rate to save power;
    // gravity shifts and the intro run at full rate.
    FrameAnimation {
        property int frame: 0

        running: field.visible && (Config.animatedBackground || Gravity.active || field.intro < 1)
        onTriggered: {
            if (!Gravity.active && field.intro >= 1 && (++frame & 1))
                return;
            field.t = Gravity.now();
            field.g = Gravity.offsetAt(field.t);
        }
    }

    // Sky, or the user's wallpaper tinted to match.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: Theme.night
            }
            GradientStop {
                position: 0.45
                color: Theme.deep
            }
            GradientStop {
                position: 0.78
                color: Theme.dusk
            }
            GradientStop {
                position: 1.0
                color: Theme.haze
            }
        }
    }

    Image {
        anchors.fill: parent
        visible: Config.wallpaper !== ""
        source: Config.wallpaper !== "" ? "file://" + Config.wallpaper : ""
        fillMode: Image.PreserveAspectCrop
        // Synchronous + cached: the lock screen must show this on its very first frame.
        asynchronous: false
        cache: true

        Rectangle {
            anchors.fill: parent
            color: Theme.night
            opacity: 0.3
        }
    }

    // Slow nebula clouds.
    GlowBlob {
        width: field.width * 0.9
        height: width
        x: field.width * 0.05 + Math.sin(field.t * 0.021) * field.width * 0.05 - field.g.x * 20
        y: -field.height * 0.35 + Math.cos(field.t * 0.017) * field.height * 0.04 - field.g.y * 20
        color: Theme.nebula
        strength: 0.22
    }
    GlowBlob {
        width: field.width * 0.7
        height: width
        x: field.width * 0.45 + Math.cos(field.t * 0.015) * field.width * 0.04 - field.g.x * 14
        y: field.height * 0.05 + Math.sin(field.t * 0.019) * field.height * 0.05 - field.g.y * 14
        color: Theme.rose
        strength: 0.10
    }

    StarDust {
        anchors.fill: parent
        scene: field
    }

    Skyline {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: field.height * 0.2
        scene: field
    }

    // Floating debris, back to front.
    Repeater {
        model: Config.debrisCount

        Debris {
            required property int index

            scene: field
            seed: index + 1
            depth: 0.32 + 0.88 * index / Math.max(1, Config.debrisCount - 1)
        }
    }

    // Kat's gravity shift: a violet ring rippling out from the centre.
    Repeater {
        id: rippleRing

        property int next: 0

        model: 3

        Rectangle {
            id: ring

            required property int index

            function fire(dx: real, dy: real, s: real): void {
                x = field.width / 2 - dx * field.width * 0.08 - width / 2;
                y = field.height / 2 - dy * field.height * 0.08 - height / 2;
                anim.restart();
            }

            width: Math.min(field.width, field.height) * 0.5
            height: width
            radius: width / 2
            color: "transparent"
            border.color: Theme.glow
            border.width: 3
            opacity: 0
            scale: 0.2

            ParallelAnimation {
                id: anim

                NumberAnimation {
                    target: ring
                    property: "scale"
                    from: 0.15
                    to: 3.2
                    duration: 1600
                    easing.type: Easing.OutCubic
                }
                SequentialAnimation {
                    NumberAnimation {
                        target: ring
                        property: "opacity"
                        to: 0.45
                        duration: 160
                    }
                    NumberAnimation {
                        target: ring
                        property: "opacity"
                        to: 0
                        duration: 1440
                        easing.type: Easing.InQuad
                    }
                }
            }
        }
    }

    Connections {
        target: Gravity
        enabled: field.ripples && field.visible

        function onKicked(dx: real, dy: real, strength: real): void {
            const ring = rippleRing.itemAt(rippleRing.next);
            rippleRing.next = (rippleRing.next + 1) % rippleRing.count;
            ring?.fire(dx, dy, strength);
        }
    }
}
