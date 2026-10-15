pragma Singleton

import QtQuick
import Quickshell

// The shared gravity field. Workspace switches, notifications and the occasional
// "gravity storm" kick it; the bar reads its offset and sways along.
Singleton {
    id: root

    readonly property real epoch: Date.now()
    // Each kick is {t0, x, y}; the field is the sum of their damped responses.
    property var kicks: []
    // True while a kick is still visibly moving things, so idle widgets can stop animating.
    property bool active: false
    // No random shifts while the screen is locked.
    property bool hold: false

    signal kicked(real dx, real dy, real strength)

    function now(): real {
        return (Date.now() - epoch) / 1000;
    }

    // Shift gravity towards (dx, dy). Magnitudes around 1 are a normal workspace switch.
    function kick(dx: real, dy: real, strength: real): void {
        const t = now();
        const s = strength ?? 1;
        const live = kicks.filter(k => t - k.t0 < 7);
        live.push({ t0: t, x: dx * s, y: dy * s });
        kicks = live;
        active = true;
        settleTimer.restart();
        kicked(dx, dy, s);
    }

    // Damped oscillation: swings toward the kick, drifts back past rest, settles.
    function offsetAt(t: real): point {
        let x = 0, y = 0;
        for (const k of kicks) {
            const d = t - k.t0;
            if (d < 0 || d > 7)
                continue;
            const r = Math.exp(-d * 0.9) * Math.sin(d * 2.2);
            x += k.x * r;
            y += k.y * r;
        }
        return Qt.point(x, y);
    }

    Timer {
        id: settleTimer
        interval: 6000
        onTriggered: root.active = false
    }

    // Ambient shifts, like the city's gravity storms.
    Timer {
        running: Config.ambientShifts && !root.hold
        repeat: true
        interval: 45000 + Math.random() * 40000
        onTriggered: {
            interval = 45000 + Math.random() * 40000;
            const a = Math.random() * Math.PI * 2;
            root.kick(Math.cos(a), Math.sin(a), 0.55);
        }
    }
}
